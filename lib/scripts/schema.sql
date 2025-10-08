-- MkuluWanga Relational Database Schema (Fused)
-- All tables, types, triggers, and relationships in one script

-- Enable UUID generation for user IDs and other UUID PKs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ENUM types for user roles, request status, and friendship status
CREATE TYPE user_role AS ENUM ('MENTEE', 'MENTOR');
CREATE TYPE request_status AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');
CREATE TYPE friendship_status AS ENUM ('PENDING','ACCEPTED','BLOCKED');
CREATE TYPE post_visibility AS ENUM ('PUBLIC', 'FRIENDS', 'PRIVATE');

-- 1. Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    -- password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone_number TEXT,
    bio TEXT,
    age INTEGER,
    gender TEXT,
    district TEXT,
    role user_role NOT NULL,
    profession TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
COMMENT ON COLUMN users.password_hash IS 'Should be a strong hash, e.g., from Argon2 or bcrypt.';
COMMENT ON COLUMN users.profession IS 'Specific to mentors, indicates their professional field.';

-- 2. Interests Table
CREATE TABLE interests (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- 3. User_Interests Table (Denormalized for simplicity)
-- Note: Uses TEXT column instead of FK to interests table for flexibility
-- The interests table serves as a reference/suggestion source only
CREATE TABLE user_interests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interest TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, interest)
);
COMMENT ON TABLE user_interests IS 'Stores user interests for mentor-mentee matching. Denormalized design for performance.';
COMMENT ON COLUMN user_interests.interest IS 'Interest name as text. Flexible design allows custom interests.';

-- 4. Mentorship_Requests Table (Relates mentee/mentor users)
CREATE TABLE mentorship_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mentee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mentor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status request_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_no_self_request CHECK (mentee_id <> mentor_id),
    UNIQUE (mentee_id, mentor_id)
);
COMMENT ON TABLE mentorship_requests IS 'Handles the lifecycle of a mentorship request.';
COMMENT ON COLUMN mentorship_requests.status IS 'Status of the request: PENDING, ACCEPTED, or REJECTED.';
COMMENT ON COLUMN mentorship_requests.updated_at IS 'Timestamp is updated when the request status changes.';

-- 5. Mentorships Table (Relates mentor/mentee users)
CREATE TABLE mentorships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mentor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mentee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_date TIMESTAMPTZ DEFAULT now(),
    UNIQUE (mentor_id, mentee_id)
);
COMMENT ON TABLE mentorships IS 'This table is populated once a request in "mentorship_requests" is ACCEPTED.';

-- 6. Notifications Table (Relates users and mentorship_requests)
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    related_request_id UUID REFERENCES mentorship_requests(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
COMMENT ON COLUMN notifications.user_id IS 'The ID of the user who should receive the notification.';
COMMENT ON COLUMN notifications.is_read IS 'Tracks if the notification has been seen, used for the notification count.';
COMMENT ON COLUMN notifications.related_request_id IS 'Optionally links a notification directly to the request that triggered it.';

-- 7. Resources Table (Relates resources to users)
CREATE TABLE resources (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id UUID REFERENCES users(id),
    cover_image_url TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
COMMENT ON TABLE resources IS 'Contains educational or informational resources for users.';
COMMENT ON COLUMN resources.content IS 'The main content of the resource, could be text, video URL, etc.';

-- 8. Online Presence Table
CREATE TABLE user_presence (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen TIMESTAMPTZ DEFAULT now()
);

-- 9. Posts Table - ADDED author_id column for compatibility
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_id UUID REFERENCES users(id), -- Added for compatibility with other files
  content TEXT,
  visibility post_visibility NOT NULL DEFAULT 'PUBLIC', -- Changed to ENUM type
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 10. Post Media Table
CREATE TABLE post_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  mime_type TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. Friendships Table
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status friendship_status NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (requester_id, addressee_id),
  CONSTRAINT chk_no_self_friendship CHECK (requester_id <> addressee_id)
);

-- 12. Messages Table
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create all indexes in one place
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_user_interests_user_id ON user_interests(user_id);
CREATE INDEX idx_user_interests_interest ON user_interests(interest);
CREATE INDEX idx_user_presence_last_seen ON user_presence(last_seen);
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_post_media_post_id ON post_media(post_id);
CREATE INDEX idx_friendships_requester_id ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee_id ON friendships(addressee_id);
CREATE INDEX idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);

-- 13. Triggers and Functions
-- Update user_presence.last_seen when is_online changes
CREATE OR REPLACE FUNCTION touch_user_presence_last_seen()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_seen = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_last_seen ON user_presence;
CREATE TRIGGER trg_touch_last_seen
BEFORE UPDATE ON user_presence
FOR EACH ROW
WHEN (OLD.is_online IS DISTINCT FROM NEW.is_online)
EXECUTE FUNCTION touch_user_presence_last_seen();

-- Notifications hooks for friendships
CREATE OR REPLACE FUNCTION notify_on_friendship_change()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    INSERT INTO notifications(user_id, message, created_at)
    VALUES (NEW.addressee_id, concat((SELECT full_name FROM users WHERE id = NEW.requester_id), ' sent you a friend request'), now());
    RETURN NEW;
  ELSIF (TG_OP = 'UPDATE' AND NEW.status = 'ACCEPTED') THEN
    INSERT INTO notifications(user_id, message, created_at)
    VALUES (NEW.requester_id, concat((SELECT full_name FROM users WHERE id = NEW.addressee_id), ' accepted your friend request'), now());
    INSERT INTO notifications(user_id, message, created_at)
    VALUES (NEW.addressee_id, concat((SELECT full_name FROM users WHERE id = NEW.requester_id), ' is now your friend'), now());
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notify_friendship ON friendships;
CREATE TRIGGER trg_notify_friendship
AFTER INSERT OR UPDATE ON friendships
FOR EACH ROW
EXECUTE FUNCTION notify_on_friendship_change();

-- Set author_id to user_id for existing posts (for backward compatibility)
UPDATE posts SET author_id = user_id WHERE author_id IS NULL;