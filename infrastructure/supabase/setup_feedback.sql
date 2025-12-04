-- Create Feedback Table
CREATE TABLE IF NOT EXISTS match_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    timeline_id UUID REFERENCES timelines(id) ON DELETE CASCADE, -- The query timeline
    match_id TEXT NOT NULL, -- The ID of the matched case (could be int or uuid depending on dataset, keeping text for flexibility)
    is_helpful BOOLEAN NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE match_feedback ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can insert their own feedback" 
ON match_feedback FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own feedback" 
ON match_feedback FOR SELECT 
USING (auth.uid() = user_id);
