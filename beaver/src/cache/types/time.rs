use std::time::{Duration, SystemTime};

use sqlx::error::BoxDynError;
use sqlx::{Decode, Encode, Sqlite};

use super::error::SqlConversionError;

#[derive(Debug, Clone)]
pub struct Timespec(pub std::time::SystemTime);

impl sqlx::Type<sqlx::Sqlite> for Timespec {
    fn type_info() -> <sqlx::Sqlite as sqlx::Database>::TypeInfo {
        <f64 as sqlx::Type::<sqlx::Sqlite>>::type_info()
    }

    fn compatible(ty: &<sqlx::Sqlite as sqlx::Database>::TypeInfo) -> bool {
        <f64 as sqlx::Type<sqlx::Sqlite>>::compatible(ty)
    }
}

impl Encode<'_, Sqlite> for Timespec {
    fn encode_by_ref(
        &self,
        buf: &mut <Sqlite as sqlx::Database>::ArgumentBuffer<'_>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        let timestampd = self.0.duration_since(SystemTime::UNIX_EPOCH).map_err(|err| Box::new(err))?;
        let timestamp = timestampd.as_secs_f64();
        Encode::<Sqlite>::encode(timestamp, buf)
    }
}

impl Decode<'_, Sqlite> for Timespec {
    fn decode(value: <Sqlite as sqlx::Database>::ValueRef<'_>) -> Result<Self, BoxDynError> {
        let res: Result<f64, BoxDynError> = Decode::<Sqlite>::decode(value);
        match res {
            Ok(timestamp) => {
                match Duration::try_from_secs_f64(timestamp).map_err(|err| Box::new(err)) {
                    Ok(dur) => {
                        if let Some(time) = SystemTime::UNIX_EPOCH.checked_add(dur) {
                            Ok(Timespec(time))
                        } else {
                            Err(Box::new(SqlConversionError::SystemTimeFromDuration(dur)) as BoxDynError)
                        }
                    },
                    Err(err) => Err(err as BoxDynError)
                }
            },
            Err(err) => Err(err)
        }
    }
}
