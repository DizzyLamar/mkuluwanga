-- Create user_interests table for interest-based matching
CREATE TABLE IF NOT EXISTS user_interests_supabase (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  interest TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, interest)
);

-- Add RLS policies
ALTER TABLE user_interests_supabase ENABLE ROW LEVEL SECURITY;

-- Anyone can view interests (for matching purposes)
CREATE POLICY "Anyone can view interests"
  ON user_interests_supabase
  FOR SELECT
  USING (true);

-- Users can manage their own interests
CREATE POLICY "Users can insert own interests"
  ON user_interests_supabase
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own interests"
  ON user_interests_supabase
  FOR DELETE
  USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_interests_user_id ON user_interests_supabase(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interests_interest ON user_interests_supabase(interest);