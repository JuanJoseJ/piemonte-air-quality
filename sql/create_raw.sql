create schema if not exists raw;

create table if not exists raw.downloads (
    download_id  bigint generated always as identity primary key,
    location_id  text        not null,
    data_date    date        not null,
    content      text        not null,
    _source_url  text        not null,
    _loaded_at   timestamptz not null default now()
);

create index if not exists downloads_location_date_idx
    on raw.downloads (location_id, data_date, _loaded_at desc);