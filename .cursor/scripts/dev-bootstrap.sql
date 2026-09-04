-- Minimal, idempotent dev bootstrap for the CoreActive backend.
--
-- The production database schema is large and lives outside this repository,
-- so it is not reproduced here. This bootstrap creates just enough for the
-- public, unauthenticated endpoints that the Flutter web client calls on
-- startup (GET /api/languages and GET /api/translations?lang=xx), which lets
-- a fresh environment prove full-stack connectivity (HTTP -> Express -> pg
-- over SSL -> PostgreSQL) without a production data dump.

CREATE TABLE IF NOT EXISTS core_languages (
  language_id SERIAL PRIMARY KEY,
  code        VARCHAR(10) UNIQUE NOT NULL,
  name        VARCHAR(100) NOT NULL,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO core_languages (code, name) VALUES
  ('tr', 'Türkçe'),
  ('en', 'English')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS core_translations (
  translation_id SERIAL PRIMARY KEY,
  language_id    INTEGER NOT NULL REFERENCES core_languages(language_id),
  key            VARCHAR(255) NOT NULL,
  value          TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (language_id, key)
);

INSERT INTO core_translations (language_id, key, value)
SELECT l.language_id, k.key, k.value
FROM core_languages l
JOIN (VALUES
  ('tr', 'app.title',    'CoreActive'),
  ('tr', 'login.button', 'Giriş Yap'),
  ('en', 'app.title',    'CoreActive'),
  ('en', 'login.button', 'Sign In')
) AS k(code, key, value) ON k.code = l.code
ON CONFLICT (language_id, key) DO NOTHING;
