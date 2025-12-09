pub use inner::*;

#[derive(thiserror::Error, Debug)]
pub enum SecretStorageError {
    #[error("Access to the secret storage was denied")]
    AccessDenied,
    #[error("Serialization error")]
    SerializationError,
    #[error("I/O error")]
    IoError,
    #[error("Unknown error")]
    UnknownError,
    #[error("Not unique")]
    NotUnique,
    #[cfg(target_os = "windows")]
    #[error("Windows error")]
    WindowsError(#[from] windows::core::Error),
}

#[cfg(target_os = "linux")]
mod inner {
    use uuid::Uuid;

    use crate::{credentials::AccountCredentials, secret::SecretStorageError};

    impl From<oo7::Error> for SecretStorageError {
        fn from(value: oo7::Error) -> Self {
            Self::from(&value)
        }
    }

    impl From<&oo7::Error> for SecretStorageError {
        fn from(value: &oo7::Error) -> Self {
            match value {
                oo7::Error::File(error) => match error {
                    oo7::file::Error::Io(_) => Self::IoError,
                    _ => Self::UnknownError,
                },
                oo7::Error::DBus(error) => match error {
                    oo7::dbus::Error::Service(service_error) => match service_error {
                        oo7::dbus::ServiceError::IsLocked(_) => Self::AccessDenied,
                        _ => Self::UnknownError,
                    },
                    oo7::dbus::Error::Dismissed => Self::AccessDenied,
                    oo7::dbus::Error::IO(_) => Self::IoError,
                    _ => Self::UnknownError,
                },
            }
        }
    }

    pub struct PlatformSecretStorage {
        keyring: oo7::Result<oo7::Keyring>,
    }

    impl PlatformSecretStorage {
        pub async fn new() -> Self {
            Self {
                keyring: oo7::Keyring::new().await,
            }
        }

        pub async fn read_credentials(&self, uuid: Uuid) -> Result<Option<AccountCredentials>, SecretStorageError> {
            let keyring = self.keyring.as_ref()?;
            keyring.unlock().await?;

            let uuid_str = uuid.as_hyphenated().to_string();
            let attributes = vec![("service", "pandora-launcher"), ("uuid", uuid_str.as_str())];

            let items = keyring.search_items(&attributes).await?;

            if items.is_empty() {
                Ok(None)
            } else if items.len() > 1 {
                Err(SecretStorageError::NotUnique)
            } else {
                let raw = items[0].secret().await?;
                Ok(Some(serde_json::from_slice(&raw).map_err(|_| SecretStorageError::SerializationError)?))
            }
        }

        pub async fn write_credentials(
            &self,
            uuid: Uuid,
            credentials: &AccountCredentials,
        ) -> Result<(), SecretStorageError> {
            let keyring = self.keyring.as_ref()?;
            keyring.unlock().await?;

            let uuid_str = uuid.as_hyphenated().to_string();
            let attributes = vec![("service", "pandora-launcher"), ("uuid", uuid_str.as_str())];

            let bytes = serde_json::to_vec(credentials).map_err(|_| SecretStorageError::SerializationError)?;

            keyring.create_item("Pandora Minecraft Account", &attributes, bytes, true).await?;
            Ok(())
        }

        pub async fn delete_credentials(&self, uuid: Uuid) -> Result<(), SecretStorageError> {
            let keyring = self.keyring.as_ref()?;
            keyring.unlock().await?;

            let uuid_str = uuid.as_hyphenated().to_string();
            let attributes = vec![("service", "pandora-launcher"), ("uuid", uuid_str.as_str())];

            keyring.delete(&attributes).await?;
            Ok(())
        }
    }
}

#[cfg(target_os = "windows")]
mod inner {
    use uuid::Uuid;

    use crate::{credentials::AccountCredentials, secret::SecretStorageError};

    use windows::Win32::Security::Credentials::*;

    pub struct PlatformSecretStorage;

    impl PlatformSecretStorage {
        pub async fn new() -> Self {
            Self
        }

        pub async fn read_credentials(&self, uuid: Uuid) -> Result<Option<AccountCredentials>, SecretStorageError> {
            let target_name = format!("PandoraLauncher_MinecraftAccount_{}", uuid.as_hyphenated());
            let mut target_name: Vec<u16> = target_name.encode_utf16().chain(Some(0)).collect();

            unsafe {
                let mut credentials: *mut CREDENTIALW = std::ptr::null_mut();

                CredReadW(
                    windows::core::PWSTR::from_raw(target_name.as_mut_ptr()),
                    CRED_TYPE_GENERIC,
                    None,
                    &mut credentials,
                )?;

                let Some(credentials) = credentials.as_mut() else {
                    return Ok(None);
                };

                let raw =
                    std::slice::from_raw_parts(credentials.CredentialBlob, credentials.CredentialBlobSize as usize);
                Ok(Some(serde_json::from_slice(&raw).map_err(|_| SecretStorageError::SerializationError)?))
            }
        }

        pub async fn write_credentials(
            &self,
            uuid: Uuid,
            credentials: &AccountCredentials,
        ) -> Result<(), SecretStorageError> {
            let mut bytes = serde_json::to_vec(credentials).map_err(|_| SecretStorageError::SerializationError)?;

            let target_name = format!("PandoraLauncher_MinecraftAccount_{}", uuid.as_hyphenated());
            let mut target_name: Vec<u16> = target_name.encode_utf16().chain(Some(0)).collect();

            let credentials = CREDENTIALW {
                Flags: CRED_FLAGS(0),
                Type: CRED_TYPE_GENERIC,
                TargetName: windows::core::PWSTR::from_raw(target_name.as_mut_ptr()),
                CredentialBlobSize: bytes.len() as u32,
                CredentialBlob: bytes.as_mut_ptr(),
                Persist: CRED_PERSIST_LOCAL_MACHINE,
                ..CREDENTIALW::default()
            };

            unsafe { CredWriteW(&credentials, 0)? };
            Ok(())
        }

        pub async fn delete_credentials(&self, uuid: Uuid) -> Result<(), SecretStorageError> {
            let target_name = format!("PandoraLauncher_MinecraftAccount_{}", uuid.as_hyphenated());
            let mut target_name: Vec<u16> = target_name.encode_utf16().chain(Some(0)).collect();

            unsafe {
                CredDeleteW(windows::core::PWSTR::from_raw(target_name.as_mut_ptr()), CRED_TYPE_GENERIC, None)?;
            }

            Ok(())
        }
    }
}

#[cfg(target_os = "macos")]
mod inner {
    use parking_lot::RwLock;
    use rustc_hash::FxHashMap;
    use uuid::Uuid;

    use crate::{credentials::AccountCredentials, secret::SecretStorageError};

    pub struct PlatformSecretStorage {
        /// In-memory cache to avoid repeated keychain prompts
        cache: RwLock<FxHashMap<Uuid, Option<AccountCredentials>>>,
    }

    impl PlatformSecretStorage {
        pub async fn new() -> Self {
            Self {
                cache: RwLock::new(FxHashMap::default()),
            }
        }

        fn get_entry(uuid: Uuid) -> Result<keyring::Entry, SecretStorageError> {
            keyring::Entry::new("pandora-launcher", &uuid.as_hyphenated().to_string())
                .map_err(|_| SecretStorageError::UnknownError)
        }

        pub async fn read_credentials(&self, uuid: Uuid) -> Result<Option<AccountCredentials>, SecretStorageError> {
            // Check cache first to avoid keychain prompt
            if let Some(cached) = self.cache.read().get(&uuid) {
                return Ok(cached.clone());
            }

            // Not in cache, read from keychain (will prompt for password)
            let entry = Self::get_entry(uuid)?;
            let result = match entry.get_secret() {
                Ok(raw) => {
                    let creds = serde_json::from_slice(&raw).map_err(|_| SecretStorageError::SerializationError)?;
                    Ok(Some(creds))
                },
                Err(keyring::Error::NoEntry) => Ok(None),
                Err(keyring::Error::Ambiguous(_)) => Err(SecretStorageError::NotUnique),
                Err(_) => Err(SecretStorageError::UnknownError),
            };

            // Cache the result
            if let Ok(ref creds) = result {
                self.cache.write().insert(uuid, creds.clone());
            }

            result
        }

        pub async fn write_credentials(
            &self,
            uuid: Uuid,
            credentials: &AccountCredentials,
        ) -> Result<(), SecretStorageError> {
            // Check if credentials have changed - skip write if msa_refresh is the same
            // (msa_refresh is the persistent token; others are derived from it)
            {
                let cache = self.cache.read();
                if let Some(Some(cached)) = cache.get(&uuid) {
                    if cached.msa_refresh == credentials.msa_refresh {
                        // No change to persistent credential, skip keychain write
                        return Ok(());
                    }
                }
            }

            // Write to keychain (will prompt for password)
            let entry = Self::get_entry(uuid)?;
            let bytes = serde_json::to_vec(credentials).map_err(|_| SecretStorageError::SerializationError)?;
            entry.set_secret(&bytes).map_err(|_| SecretStorageError::UnknownError)?;

            // Update cache
            self.cache.write().insert(uuid, Some(credentials.clone()));
            Ok(())
        }

        pub async fn delete_credentials(&self, uuid: Uuid) -> Result<(), SecretStorageError> {
            let entry = Self::get_entry(uuid)?;
            entry.delete_credential().map_err(|_| SecretStorageError::UnknownError)?;

            // Remove from cache
            self.cache.write().remove(&uuid);
            Ok(())
        }
    }
}
