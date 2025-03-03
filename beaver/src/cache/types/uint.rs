use sqlx::error::BoxDynError;
use sqlx::{Decode, Encode, Sqlite};

#[derive(Debug, Clone)]
pub struct UInt(pub u64);

impl sqlx::Type<sqlx::Sqlite> for UInt {
    fn type_info() -> <sqlx::Sqlite as sqlx::Database>::TypeInfo {
        <i64 as sqlx::Type::<sqlx::Sqlite>>::type_info()
    }

    fn compatible(ty: &<sqlx::Sqlite as sqlx::Database>::TypeInfo) -> bool {
        <i64 as sqlx::Type::<sqlx::Sqlite>>::compatible(ty)
    }
}

impl Encode<'_, Sqlite> for UInt {
    fn encode_by_ref(
        &self,
        buf: &mut <Sqlite as sqlx::Database>::ArgumentBuffer<'_>,
    ) -> Result<sqlx::encode::IsNull, sqlx::error::BoxDynError> {
        Encode::<Sqlite>::encode(unsafe { std::mem::transmute::<u64, i64>(self.0) }, buf)
    }
}

impl Decode<'_, Sqlite> for UInt {
    fn decode(value: <Sqlite as sqlx::Database>::ValueRef<'_>) -> Result<Self, sqlx::error::BoxDynError> {
        let res: Result<i64, BoxDynError> = Decode::<Sqlite>::decode(value);
        res.map(|i| UInt(unsafe { std::mem::transmute::<i64, u64>(i) }))
    }
}
