CREATE TABLE users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    display_name text,
    timezone text DEFAULT 'UTC',
    language_preference text DEFAULT 'en',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE hebrew_calendar_dates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hebrew_date date NOT NULL,
    gregorian_date date NOT NULL,
    parasha text,
    holiday_name text,
    is_rosh_chodesh boolean DEFAULT false,
    is_shabbat boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(hebrew_date, gregorian_date)
);

CREATE TABLE user_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    hebrew_date_id uuid REFERENCES hebrew_calendar_dates(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    is_custom_holiday boolean DEFAULT false,
    event_color text DEFAULT '#3B82F6',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE reminders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    user_event_id uuid REFERENCES user_events(id) ON DELETE CASCADE,
    system_event_id uuid REFERENCES hebrew_calendar_dates(id) ON DELETE CASCADE,
    notify_at timestamptz NOT NULL,
    notification_method text DEFAULT 'in_app' CHECK (notification_method IN ('in_app', 'email')),
    is_sent boolean DEFAULT false,
    sent_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_hebrew_calendar_dates_hebrew ON hebrew_calendar_dates(hebrew_date);
CREATE INDEX idx_hebrew_calendar_dates_gregorian ON hebrew_calendar_dates(gregorian_date);
CREATE INDEX idx_user_events_user_id ON user_events(user_id);
CREATE INDEX idx_user_events_hebrew_date_id ON user_events(hebrew_date_id);
CREATE INDEX idx_reminders_user_id ON reminders(user_id);
CREATE INDEX idx_reminders_user_event_id ON reminders(user_event_id);
CREATE INDEX idx_reminders_system_event_id ON reminders(system_event_id);
CREATE INDEX idx_reminders_notify_at ON reminders(notify_at);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hebrew_calendar_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
ON users FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Calendar dates are public for viewing"
ON hebrew_calendar_dates FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Only admins can modify calendar dates"
ON hebrew_calendar_dates FOR ALL
TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.email LIKE '%@admin.hebraiccalendar.com'))
WITH CHECK (EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.email LIKE '%@admin.hebraiccalendar.com'));

CREATE POLICY "Users can manage their own events"
ON user_events FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can manage their own reminders"
ON reminders FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hebrew_calendar_dates_updated_at BEFORE UPDATE ON hebrew_calendar_dates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_events_updated_at BEFORE UPDATE ON user_events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reminders_updated_at BEFORE UPDATE ON reminders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();