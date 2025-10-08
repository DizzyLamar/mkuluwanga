-- Add category column to resources table (linked to interests)
ALTER TABLE resources ADD COLUMN IF NOT EXISTS category TEXT;

-- Add is_anonymous column to posts table for mentor anonymous posting
ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE;

-- Create index for faster category filtering
CREATE INDEX IF NOT EXISTS idx_resources_category ON resources(category);

-- Create index for anonymous posts
CREATE INDEX IF NOT EXISTS idx_posts_is_anonymous ON posts(is_anonymous);

COMMENT ON COLUMN resources.category IS 'Resource category, should match an interest name for filtering';
COMMENT ON COLUMN posts.is_anonymous IS 'If true, post author identity is hidden (mentors only)';
