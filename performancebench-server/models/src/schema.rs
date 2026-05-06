// @generated — Diesel schema definitions matching SQL DDL

diesel::table! {
    users (id) {
        id -> Uuid,
        email -> Varchar,
        password_hash -> Nullable<Varchar>,
        display_name -> Nullable<Varchar>,
        role -> Varchar,
        is_active -> Bool,
        sso_provider -> Nullable<Varchar>,
        sso_subject -> Nullable<Varchar>,
        auth_source -> Varchar,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    api_tokens (id) {
        id -> Uuid,
        user_id -> Uuid,
        name -> Varchar,
        token_prefix -> Varchar,
        token_hash -> Varchar,
        scopes -> Array<Text>,
        last_used_at -> Nullable<Timestamptz>,
        expires_at -> Nullable<Timestamptz>,
        is_revoked -> Bool,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    refresh_tokens (id) {
        id -> Uuid,
        user_id -> Uuid,
        token_hash -> Varchar,
        expires_at -> Timestamptz,
        is_revoked -> Bool,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    devices (id) {
        id -> Uuid,
        name -> Nullable<Varchar>,
        model -> Nullable<Varchar>,
        os_type -> Varchar,
        os_version -> Nullable<Varchar>,
        chipset -> Nullable<Varchar>,
        serial_number -> Nullable<Varchar>,
        first_seen_at -> Timestamptz,
        last_seen_at -> Timestamptz,
    }
}

diesel::table! {
    sessions (id) {
        id -> Uuid,
        user_id -> Uuid,
        device_id -> Nullable<Uuid>,
        app_name -> Varchar,
        app_package -> Nullable<Varchar>,
        app_version -> Nullable<Varchar>,
        device_model -> Nullable<Varchar>,
        device_os_version -> Nullable<Varchar>,
        chipset -> Nullable<Varchar>,
        tags -> Array<Text>,
        project_id -> Nullable<Varchar>,
        collection_id -> Nullable<Uuid>,
        notes -> Nullable<Text>,
        started_at -> Timestamptz,
        ended_at -> Nullable<Timestamptz>,
        duration_seconds -> Nullable<Int4>,
        session_stats -> Jsonb,
        metric_samples -> Jsonb,
        markers -> Jsonb,
        detected_issues -> Jsonb,
        screenshots -> Array<Text>,
        video_metadata -> Nullable<Jsonb>,
        thumbnail_path -> Nullable<Text>,
        is_uploaded -> Bool,
        uploaded_by -> Nullable<Uuid>,
        uploaded_at -> Nullable<Timestamptz>,
        team_project_id -> Nullable<Uuid>,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    markers (id) {
        id -> Uuid,
        session_id -> Uuid,
        name -> Varchar,
        marker_type -> Varchar,
        started_at -> Int8,
        ended_at -> Nullable<Int8>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    detected_issues (id) {
        id -> Uuid,
        session_id -> Uuid,
        rule_id -> Varchar,
        category -> Varchar,
        severity -> Varchar,
        message -> Text,
        details -> Jsonb,
        timestamp -> Int8,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    collections (id) {
        id -> Uuid,
        user_id -> Uuid,
        name -> Varchar,
        description -> Nullable<Text>,
        tags -> Array<Text>,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    lenses (id) {
        id -> Uuid,
        user_id -> Uuid,
        name -> Varchar,
        description -> Nullable<Text>,
        filters -> Jsonb,
        chart_config -> Jsonb,
        is_public -> Bool,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    alert_rules (id) {
        id -> Uuid,
        user_id -> Uuid,
        name -> Varchar,
        metric_name -> Varchar,
        condition -> Varchar,
        threshold -> Float8,
        duration_seconds -> Int4,
        channels -> Jsonb,
        is_active -> Bool,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    alert_events (id) {
        id -> Uuid,
        rule_id -> Uuid,
        session_id -> Nullable<Uuid>,
        metric_value -> Float8,
        threshold -> Float8,
        fired_at -> Timestamptz,
        acknowledged_at -> Nullable<Timestamptz>,
        acknowledged_by -> Nullable<Uuid>,
    }
}

diesel::table! {
    videos (id) {
        id -> Uuid,
        session_id -> Uuid,
        file_path -> Text,
        chunk_index -> Int4,
        codec -> Nullable<Varchar>,
        width -> Nullable<Int4>,
        height -> Nullable<Int4>,
        fps -> Nullable<Int4>,
        bitrate_kbps -> Nullable<Int4>,
        duration_seconds -> Nullable<Int4>,
        file_size_bytes -> Nullable<Int8>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    sso_configs (id) {
        id -> Uuid,
        provider_type -> Varchar,
        name -> Varchar,
        config -> Jsonb,
        is_active -> Bool,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    webhook_configs (id) {
        id -> Uuid,
        user_id -> Uuid,
        name -> Varchar,
        url -> Text,
        secret -> Nullable<Varchar>,
        events -> Array<Text>,
        is_active -> Bool,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    audit_events (id) {
        id -> Uuid,
        event_type -> Varchar,
        event_category -> Varchar,
        actor_id -> Nullable<Uuid>,
        actor_email -> Nullable<Varchar>,
        target_type -> Nullable<Varchar>,
        target_id -> Nullable<Uuid>,
        details -> Jsonb,
        ip_address -> Nullable<Inet>,
        user_agent -> Nullable<Text>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    team_orgs (id) {
        id -> Uuid,
        name -> Varchar,
        slug -> Varchar,
        description -> Nullable<Text>,
        is_active -> Bool,
        settings -> Jsonb,
        created_by -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    team_projects (id) {
        id -> Uuid,
        org_id -> Uuid,
        name -> Varchar,
        slug -> Varchar,
        description -> Nullable<Text>,
        is_active -> Bool,
        created_by -> Uuid,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    team_membership (id) {
        id -> Uuid,
        user_id -> Uuid,
        org_id -> Uuid,
        role -> Varchar,
        joined_at -> Timestamptz,
    }
}

diesel::joinable!(api_tokens -> users (user_id));
diesel::joinable!(refresh_tokens -> users (user_id));
diesel::joinable!(sessions -> users (user_id));
diesel::joinable!(sessions -> devices (device_id));
diesel::joinable!(markers -> sessions (session_id));
diesel::joinable!(detected_issues -> sessions (session_id));
diesel::joinable!(collections -> users (user_id));
diesel::joinable!(lenses -> users (user_id));
diesel::joinable!(alert_rules -> users (user_id));
diesel::joinable!(alert_events -> alert_rules (rule_id));
diesel::joinable!(videos -> sessions (session_id));
diesel::joinable!(webhook_configs -> users (user_id));
diesel::joinable!(audit_events -> users (actor_id));
diesel::joinable!(team_projects -> team_orgs (org_id));
diesel::joinable!(team_membership -> users (user_id));
diesel::joinable!(team_membership -> team_orgs (org_id));

diesel::allow_tables_to_appear_in_same_query!(
    users,
    sso_configs,
    api_tokens,
    refresh_tokens,
    devices,
    sessions,
    markers,
    detected_issues,
    collections,
    lenses,
    alert_rules,
    alert_events,
    videos,
    webhook_configs,
    audit_events,
    team_orgs,
    team_projects,
    team_membership,
);
