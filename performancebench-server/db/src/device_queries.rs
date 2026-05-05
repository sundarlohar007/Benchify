use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::device::DeviceInfo;
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::devices;

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Upsert device info — INSERT ON CONFLICT (serial_number) DO UPDATE.
pub async fn upsert_device(
    pool: &DbPool,
    name: Option<&str>,
    model: Option<&str>,
    os_type: &str,
    os_version: Option<&str>,
    chipset: Option<&str>,
    serial_number: Option<&str>,
) -> DbResult<DeviceInfo> {
    let mut client = pool.get().await?;
    let new_id = Uuid::new_v4();
    let now = chrono::Utc::now().naive_utc();

    // If serial_number is provided, use ON CONFLICT logic.
    // Otherwise, just insert (no upsert possible without a unique key).
    if let Some(serial) = serial_number {
        let result = diesel::insert_into(devices::table)
            .values((
                devices::id.eq(new_id),
                devices::name.eq(name),
                devices::model.eq(model),
                devices::os_type.eq(os_type),
                devices::os_version.eq(os_version),
                devices::chipset.eq(chipset),
                devices::serial_number.eq(Some(serial.to_string())),
                devices::first_seen_at.eq(now),
                devices::last_seen_at.eq(now),
            ))
            .on_conflict(devices::serial_number)
            .do_update()
            .set((
                devices::name.eq(name),
                devices::model.eq(model),
                devices::os_version.eq(os_version),
                devices::chipset.eq(chipset),
                devices::last_seen_at.eq(now),
            ))
            .get_result::<DeviceInfo>(&mut *client)
            .await?;
        Ok(result)
    } else {
        let result = diesel::insert_into(devices::table)
            .values((
                devices::id.eq(new_id),
                devices::name.eq(name),
                devices::model.eq(model),
                devices::os_type.eq(os_type),
                devices::os_version.eq(os_version),
                devices::chipset.eq(chipset),
                devices::first_seen_at.eq(now),
                devices::last_seen_at.eq(now),
            ))
            .get_result::<DeviceInfo>(&mut *client)
            .await?;
        Ok(result)
    }
}

/// List devices associated with sessions owned by the given user.
/// Joins sessions to find devices the user has profiling data for.
pub async fn list_devices_for_user(
    pool: &DbPool,
    user_id: Uuid,
) -> DbResult<Vec<DeviceInfo>> {
    use crate::schema::sessions;

    let mut client = pool.get().await?;

    // Find distinct devices from the user's sessions
    let device_ids = sessions::table
        .filter(sessions::user_id.eq(user_id))
        .filter(sessions::device_id.is_not_null())
        .select(sessions::device_id)
        .distinct()
        .load::<Option<Uuid>>(&mut *client)
        .await?;

    let ids: Vec<Uuid> = device_ids.into_iter().filter_map(|id| id).collect();

    if ids.is_empty() {
        return Ok(vec![]);
    }

    let result = devices::table
        .filter(devices::id.eq_any(&ids))
        .order(devices::last_seen_at.desc())
        .load::<DeviceInfo>(&mut *client)
        .await?;
    Ok(result)
}

/// Get a single device by ID.
pub async fn get_device(pool: &DbPool, device_id: Uuid) -> DbResult<Option<DeviceInfo>> {
    let mut client = pool.get().await?;
    let result = devices::table
        .find(device_id)
        .first::<DeviceInfo>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// Get session count for a device.
pub async fn get_device_session_count(
    pool: &DbPool,
    device_id: Uuid,
    user_id: Uuid,
) -> DbResult<i64> {
    use crate::schema::sessions;

    let mut client = pool.get().await?;
    let count: i64 = sessions::table
        .filter(sessions::device_id.eq(Some(device_id)))
        .filter(sessions::user_id.eq(user_id))
        .count()
        .get_result(&mut *client)
        .await?;
    Ok(count)
}
