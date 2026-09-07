ALTER TABLE todos ADD COLUMN status TEXT DEFAULT 'todo';
CREATE INDEX idx_todos_status ON todos(status);
-- Backfill: set existing completed todos to 'done'
UPDATE todos SET status = 'done' WHERE is_completed = true;
