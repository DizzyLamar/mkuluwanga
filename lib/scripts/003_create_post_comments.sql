-- Create post_comments table for Instagram-style comments
CREATE TABLE IF NOT EXISTS post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_created_at ON post_comments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Add author_id to posts table if it doesn't exist
ALTER TABLE posts ADD COLUMN IF NOT EXISTS author_id UUID REFERENCES users(id);
-- Update existing posts to set author_id = user_id
UPDATE posts SET author_id = user_id WHERE author_id IS NULL;

-- Policy: Users can view comments on posts they can see
CREATE POLICY "Users can view comments on visible posts" ON post_comments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM posts
      WHERE posts.id = post_comments.post_id
      AND (
        posts.visibility = 'PUBLIC'
        OR posts.user_id = auth.uid()
        OR posts.author_id = auth.uid()
      )
    )
  );

-- Policy: Users can create comments on posts they can see
CREATE POLICY "Users can create comments on visible posts" ON post_comments
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM posts
      WHERE posts.id = post_comments.post_id
      AND (
        posts.visibility = 'PUBLIC'
        OR posts.author_id = auth.uid()
        OR posts.user_id = auth.uid()
        OR (
          posts.visibility = 'FRIENDS'
          AND EXISTS (
            SELECT 1 FROM friendships
            WHERE friendships.status = 'ACCEPTED'
            AND (
              (friendships.requester_id = auth.uid() AND friendships.addressee_id = posts.user_id)
              OR (friendships.addressee_id = auth.uid() AND friendships.requester_id = posts.user_id)
            )
          )
        )
      )
    )
  );

-- Policy: Users can update their own comments
CREATE POLICY "Users can update own comments" ON post_comments
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy: Users can delete their own comments
CREATE POLICY "Users can delete own comments" ON post_comments
  FOR DELETE
  USING (user_id = auth.uid());

  CREATE TABLE IF NOT EXISTS post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensures a user can only like a post once
    UNIQUE (post_id, user_id)
  );

  -- Create index for faster lookup of likes on a post
  CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
  CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);