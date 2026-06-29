-- Fase 0: esquema inicial

CREATE TYPE user_role AS ENUM ('Free', 'Pro', 'Admin');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'blocked');
CREATE TYPE room_status AS ENUM ('waiting', 'in_progress', 'finished');
CREATE TYPE reaction_mode AS ENUM ('timer', 'pass');

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'Free',
    status user_status NOT NULL DEFAULT 'active',
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    fcm_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code CHAR(6) UNIQUE NOT NULL,
    qr_payload TEXT,
    host_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    max_players SMALLINT NOT NULL DEFAULT 6 CHECK (max_players BETWEEN 2 AND 12),
    turn_limit_seconds SMALLINT,
    reaction_mode reaction_mode NOT NULL DEFAULT 'timer',
    reaction_time_seconds SMALLINT,
    status room_status NOT NULL DEFAULT 'waiting',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE room_players (
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    seat_order SMALLINT,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (room_id, user_id)
);

CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id),
    deck_variant SMALLINT NOT NULL,   -- 15 o 30 cartas
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    winner_id UUID REFERENCES users(id)
);

CREATE TABLE action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id),
    turn_number SMALLINT NOT NULL,
    actor_id UUID NOT NULL REFERENCES users(id),
    action_type VARCHAR(50) NOT NULL,
    target_id UUID REFERENCES users(id),
    result VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_stats (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    games_played INT NOT NULL DEFAULT 0,
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    avg_players NUMERIC(4,2)
);