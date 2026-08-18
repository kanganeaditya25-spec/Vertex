from sqlalchemy import Engine, inspect, text


ORGANIZATION_ADDITIVE_COLUMNS = {
    "organization_projects": {
        "linked_asset_ids": "JSON NOT NULL DEFAULT '[]'",
        "linked_reminder_ids": "JSON NOT NULL DEFAULT '[]'",
        "status_options": "JSON NOT NULL DEFAULT '[]'",
    },
}


def ensure_additive_schema(engine: Engine) -> None:
    inspector = inspect(engine)
    for table_name, columns in ORGANIZATION_ADDITIVE_COLUMNS.items():
        if table_name not in inspector.get_table_names():
            continue
        existing = {column["name"] for column in inspector.get_columns(table_name)}
        for name, definition in columns.items():
            if name in existing:
                continue
            with engine.begin() as connection:
                connection.execute(text(f'ALTER TABLE "{table_name}" ADD COLUMN "{name}" {definition}'))
