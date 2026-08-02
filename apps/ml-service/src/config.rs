use anyhow::{Context, Result};
use std::env;
use std::path::{Path, PathBuf};

pub const LABELS: [&str; 4] = ["Bercak Daun", "Daun Sehat", "Hawar Daun", "Karat Daun"];
pub const SERVICE_NAME: &str = "zeavis-ml-service";
pub const SERVICE_VERSION: &str = env!("CARGO_PKG_VERSION");
pub const DEFAULT_INPUT_SIZE: u32 = 224;
pub const DEFAULT_MODEL_PATH: &str = "../../Machine_Learning/model/model.onnx";
pub const DEFAULT_TEMPERATURE: f32 = 1.0;
pub const CONFIDENCE_THRESHOLD_HIGH: f32 = 0.70;
pub const CONFIDENCE_THRESHOLD_LOW: f32 = 0.45;

#[derive(Clone, Debug, PartialEq)]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub model_path: PathBuf,
    pub input_size: u32,
    pub temperature: f32,
    pub conf_threshold_high: f32,
    pub conf_threshold_low: f32,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        let base_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        Self::from_env_with_base_dir(&base_dir)
    }

    pub fn from_env_with_base_dir(base_dir: &Path) -> Result<Self> {
        let host = env::var("ML_SERVICE_HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
        let port = parse_env_u16("ML_SERVICE_PORT", 4012)?;
        let input_size = parse_env_u32("MODEL_INPUT_SIZE", DEFAULT_INPUT_SIZE)?;
        let model_path = env::var("MODEL_PATH").unwrap_or_else(|_| DEFAULT_MODEL_PATH.to_string());
        let temperature = parse_env_f32("MODEL_TEMPERATURE", DEFAULT_TEMPERATURE)?;
        let conf_threshold_high = parse_env_f32("MODEL_CONF_HIGH", CONFIDENCE_THRESHOLD_HIGH)?;
        let conf_threshold_low = parse_env_f32("MODEL_CONF_LOW", CONFIDENCE_THRESHOLD_LOW)?;

        Ok(Self {
            host,
            port,
            model_path: resolve_model_path(base_dir, &model_path),
            input_size,
            temperature,
            conf_threshold_high,
            conf_threshold_low,
        })
    }
}

pub fn resolve_model_path(base_dir: &Path, model_path: &str) -> PathBuf {
    let path = PathBuf::from(model_path);
    if path.is_absolute() {
        path
    } else {
        base_dir.join(path)
    }
}

fn parse_env_u16(name: &str, default: u16) -> Result<u16> {
    match env::var(name) {
        Ok(value) => value
            .parse::<u16>()
            .with_context(|| format!("{name} must be a valid u16")),
        Err(_) => Ok(default),
    }
}

fn parse_env_u32(name: &str, default: u32) -> Result<u32> {
    match env::var(name) {
        Ok(value) => value
            .parse::<u32>()
            .with_context(|| format!("{name} must be a valid u32")),
        Err(_) => Ok(default),
    }
}

fn parse_env_f32(name: &str, default: f32) -> Result<f32> {
    match env::var(name) {
        Ok(value) => value
            .parse::<f32>()
            .with_context(|| format!("{name} must be a valid f32")),
        Err(_) => Ok(default),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn labels_match_training_class_order_with_display_names() {
        assert_eq!(LABELS, ["Bercak Daun", "Daun Sehat", "Hawar Daun", "Karat Daun"]);
    }

    #[test]
    fn relative_model_path_resolves_from_service_directory() {
        let base = Path::new("/repo/apps/ml-service");
        let resolved = resolve_model_path(base, "../../Machine_Learning/model/model.onnx");
        assert_eq!(resolved, PathBuf::from("/repo/apps/ml-service/../../Machine_Learning/model/model.onnx"));
    }

    #[test]
    fn absolute_model_path_is_preserved() {
        let base = Path::new("/repo/apps/ml-service");
        let resolved = resolve_model_path(base, "/models/model.onnx");
        assert_eq!(resolved, PathBuf::from("/models/model.onnx"));
    }

    #[test]
    fn config_uses_default_values_when_env_is_absent() {
        temp_env::with_vars_unset(
            ["ML_SERVICE_HOST", "ML_SERVICE_PORT", "MODEL_PATH", "MODEL_INPUT_SIZE"],
            || {
                let config = Config::from_env_with_base_dir(Path::new("/repo/apps/ml-service")).unwrap();

                assert_eq!(config.host, "0.0.0.0");
                assert_eq!(config.port, 4012);
                assert_eq!(config.input_size, 224);
                assert_eq!(
                    config.model_path,
                    PathBuf::from("/repo/apps/ml-service/../../Machine_Learning/model/model.onnx")
                );
            },
        );
    }

    #[test]
    fn config_reads_environment_overrides() {
        temp_env::with_vars(
            [
                ("ML_SERVICE_HOST", Some("127.0.0.1")),
                ("ML_SERVICE_PORT", Some("9000")),
                ("MODEL_PATH", Some("/tmp/model.onnx")),
                ("MODEL_INPUT_SIZE", Some("128")),
            ],
            || {
                let config = Config::from_env_with_base_dir(Path::new("/repo/apps/ml-service")).unwrap();

                assert_eq!(config.host, "127.0.0.1");
                assert_eq!(config.port, 9000);
                assert_eq!(config.input_size, 128);
                assert_eq!(config.model_path, PathBuf::from("/tmp/model.onnx"));
            },
        );
    }

    #[test]
    fn invalid_port_returns_error() {
        temp_env::with_vars(
            [("ML_SERVICE_PORT", Some("not-a-port"))],
            || {
                let error = Config::from_env_with_base_dir(Path::new("/repo/apps/ml-service")).unwrap_err();
                assert!(error.to_string().contains("ML_SERVICE_PORT"));
            },
        );
    }
}
