## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Database Schema](#database-schema)
5. [Implementation Analysis](#implementation-analysis)
6. [Identified Issues & Faults](#identified-issues--faults)
7. [Underutilization & Missing Features](#underutilization--missing-features)
8. [Security Analysis](#security-analysis)
9. [Recommendations](#recommendations)

---

## Overview

**MkuluWanga** is a Flutter-based mentorship and social networking application designed to connect mentors and mentees. The app provides features for:
- Role-based dashboards (Mentor/Mentee)
- Social posting and interaction
- Private journaling (Vault)
- Educational resources
- Real-time messaging
- Anonymous support
- Interest-based matching

**Technology Stack:**
- Frontend: Flutter/Dart
- Backend: Supabase (PostgreSQL + Real-time + Authentication)
- Authentication: Supabase Email/Password
- State Management: StatefulWidget with setState

---

## Architecture

### Directory Structure
```
lib/
├── main.dart                    # App entry point & Supabase initialization
├── auth_gate.dart               # Authentication state manager
├── screens/                     # UI screens (21 screens)
│   ├── welcome_screen.dart
│   ├── login_screen.dart
│   ├── signup_flow/
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   ├── mentor_dashboard_screen.dart
│   ├── mentees_dashboard_screen.dart
│   ├── vault_screen.dart
│   ├── chat_screen.dart
│   ├── home_feed_screen.dart
│   ├── resources_feed_screen.dart
│   └── ... (other screens)
├── widgets/                     # Reusable UI components (10 widgets)
│   ├── post_card.dart
│   ├── resource_card.dart
│   ├── app_main_bar.dart
│   ├── comments_bottom_sheet.dart
│   └── ... (other widgets)
├── services/                    # Business logic services
│   ├── cache_service.dart
│   └── image_service.dart
└── scripts/                     # Database migration scripts
    ├── schema.sql
    ├── 001_create_journal_entries.sql
    ├── 002_create_user_interests.sql
    ├── 003_create_post_comments.sql
    └── ... (other migration scripts)
```

### Key Design Patterns
- **Singleton Pattern**: CacheService for centralized caching
- **Factory Constructor**: CacheService instance management
- **State Management**: StatefulWidget with lifecycle methods
- **Real-time Subscriptions**: Supabase real-time channels for messages
- **Future/Async Pattern**: Async data fetching with FutureBuilder
- **Keep Alive Mixin**: Used in HomeFeedScreen and ResourcesFeedScreen to preserve state

---

## Features

### 1. Authentication & Authorization
**Location**: `auth_gate.dart`, `login_screen.dart`, `signup_flow/`

**Implemented:**
- Email/password authentication via Supabase
- Session persistence and restoration
- Email confirmation check (users without confirmed emails are signed out)
- Role-based routing (MENTOR vs MENTEE)
- Auth state listener for automatic navigation

**User Flow:**
1. WelcomeScreen → Login/Signup
2. AuthGate checks session
3. Routes to appropriate dashboard based on role

### 2. Role-Based Dashboards

#### Mentor Dashboard
**Location**: `mentor_dashboard_screen.dart`

**Features:**
- **Impact Analytics**:
  - Total mentees
  - Messages sent
  - Conversations count
  - Support responses
  - Average response time
  - Impact score calculation
  - 7-day activity trend chart
- **Mentorship Request Management**: Accept/reject incoming requests
- **Active Mentees Tracker**: Shows mentees active in last 7 days
- **Resource Creation**: Mentors can create educational resources
- **Pull-to-refresh**: Updates all analytics

**Analytics Calculation:**
```dart
impactScore = (messagesSent * 2) +
              (supportResponses * 5) +
              (totalResources * 10) +
              (totalPosts * 3)
```

#### Mentee Dashboard
**Location**: `mentees_dashboard_screen.dart`

**Features:**
- Browse available mentors
- District-based sorting (same district mentors appear first)
- Send mentorship requests
- View mentor profiles (name, profession, district)
- Duplicate request prevention

### 3. Social Feed
**Location**: `home_feed_screen.dart`, `post_card.dart`

**Features:**
- Instagram-style post feed
- Post visibility levels: PUBLIC, FRIENDS, PRIVATE
- Client-side filtering based on visibility rules
- Like/unlike posts with animation
- Comment system via bottom sheet
- Create posts with media
- Double-tap to like photos
- "View All Posts" navigation
- Pull-to-refresh
- Empty state handling

**Visibility Logic:**
```dart
Show post if:
  - User is the author, OR
  - Post is PUBLIC, OR
  - Post is FRIENDS and user is friends with author
```

**⚠️ CRITICAL ISSUE**: RLS is disabled on posts table, relying on client-side filtering

### 4. Private Vault (Journal)
**Location**: `vault_screen.dart`

**Features:**
- Private journal entries (title + content)
- Search functionality across title and content
- Create/Edit/Delete entries
- Chronological ordering (newest first)
- Mood field (defined in schema but not implemented in UI)
- Secure RLS policies (users can only access their own entries)

### 5. Messaging System
**Location**: `chat_screen.dart`, `messages_screen.dart`, `anonymous_chat_screen.dart`

**Features:**
- Direct messaging between users
- Conversation list with last message preview
- Real-time message updates via Supabase channels
- Online user presence indicator
- Anonymous support messaging
- Optimistic UI updates
- Split-pane UI (conversation list + active chat)

**Real-time Implementation:**
```dart
_supabase.channel('messages:${user.id}')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    table: 'messages',
    callback: (payload) { /* Update UI */ }
  )
  .subscribe();
```

### 6. Resources Feed
**Location**: `resources_feed_screen.dart`, `resource_card.dart`

**Features:**
- Browse educational resources
- Search by title, author, or summary
- Category filtering (All, Career, Skills, Personal, Business)
- Resource detail view
- Cached responses (10-minute TTL)
- Pull-to-refresh
- Mentor-created resources display author info

**⚠️ ISSUE**: Categories are UI-only; no category column in database

### 7. Interest Matching
**Location**: `interest_matching_screen.dart`

**Features:**
- Find users with similar interests
- Interest-based mentor recommendations

**⚠️ CRITICAL ISSUE**: Table name mismatch
- Schema defines: `user_interests` (many-to-many with interests table)
- Migration script creates: `user_interests_supabase`
- Code likely references: `user_interests`

### 8. Profile Management
**Location**: `profile_screen.dart`, `edit_profile_screen.dart`

**Features:**
- View profile (avatar, bio, profession, district, role)
- Edit profile information
- Avatar upload capability
- Display member-since date
- Logout functionality
- Explicit navigation to LoginScreen on logout

### 9. Friendships
**Location**: Referenced in `home_feed_screen.dart`, `friends_screen.dart`

**Features:**
- Send/accept friend requests
- Friend status: PENDING, ACCEPTED, BLOCKED
- Auto-notifications via database triggers
- Used for post visibility filtering

### 10. Notifications
**Location**: `notifications_screen.dart`, `notification_icon.dart`

**Features:**
- Bell icon with unread count badge
- Notification popup
- Real-time notifications
- Mark as read
- Related to mentorship requests and friendships

### 11. Anonymous Support Hub
**Location**: `anonymous_support_screen.dart`, `anonymous_chat_screen.dart`

**Features:**
- Anonymous messaging capability
- Support request posting
- Responder dashboard for mentors

**⚠️ ISSUE**: References `support_responses` table not defined in main schema

---

## Database Schema

### Core Tables

#### users
```sql
- id (UUID, PK)
- email (TEXT, UNIQUE)
- full_name (TEXT)
- phone_number (TEXT)
- bio (TEXT)
- age (INTEGER)
- gender (TEXT)
- district (TEXT)
- role (user_role ENUM: MENTEE, MENTOR)
- profession (TEXT)
- created_at (TIMESTAMPTZ)
```

#### posts
```sql
- id (UUID, PK)
- user_id (UUID, FK → users)
- author_id (UUID, FK → users)  -- ⚠️ Duplicate column
- content (TEXT)
- visibility (post_visibility ENUM: PUBLIC, FRIENDS, PRIVATE)
- created_at (TIMESTAMPTZ)
```

**⚠️ SCHEMA ISSUE**: Both `user_id` and `author_id` exist. Code uses `author_id`, but this creates confusion.

#### post_media
```sql
- id (UUID, PK)
- post_id (UUID, FK → posts)
- url (TEXT) or media_url (TEXT)  -- ⚠️ Inconsistent naming
- mime_type or media_type (TEXT)  -- ⚠️ Inconsistent naming
- created_at (TIMESTAMPTZ)
```

#### post_likes
```sql
- id (UUID, PK)
- post_id (UUID, FK → posts)
- user_id (UUID, FK → users)
- created_at (TIMESTAMPTZ)
- UNIQUE(post_id, user_id)
```

#### post_comments
```sql
- id (UUID, PK)
- post_id (UUID, FK → posts)
- user_id (UUID, FK → users)
- content (TEXT)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

#### journal_entries
```sql
- id (UUID, PK)
- user_id (UUID, FK → users)
- title (TEXT)
- content (TEXT)
- mood (TEXT)  -- ⚠️ Defined but not used in UI
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
```

#### friendships
```sql
- id (UUID, PK)
- requester_id (UUID, FK → users)
- addressee_id (UUID, FK → users)
- status (friendship_status ENUM: PENDING, ACCEPTED, BLOCKED)
- created_at (TIMESTAMPTZ)
- UNIQUE(requester_id, addressee_id)
- CONSTRAINT: requester_id ≠ addressee_id
```

#### messages
```sql
- id (UUID, PK)
- sender_id (UUID, FK → users)
- receiver_id (UUID, FK → users)
- body (TEXT)
- is_read (BOOLEAN)
- is_anonymous (BOOLEAN)
- created_at (TIMESTAMPTZ)
```

#### mentorship_requests
```sql
- id (UUID, PK)
- mentee_id (UUID, FK → users)
- mentor_id (UUID, FK → users)
- status (request_status ENUM: PENDING, ACCEPTED, REJECTED)
- created_at (TIMESTAMPTZ)
- updated_at (TIMESTAMPTZ)
- UNIQUE(mentee_id, mentor_id)
- CONSTRAINT: mentee_id ≠ mentor_id
```

#### mentorships
```sql
- id (UUID, PK)
- mentor_id (UUID, FK → users)
- mentee_id (UUID, FK → users)
- start_date (TIMESTAMPTZ)
- UNIQUE(mentor_id, mentee_id)
```

#### resources
```sql
- id (SERIAL, PK)
- title (TEXT)
- summary (TEXT)
- content (TEXT)
- author_id (UUID, FK → users)
- cover_image_url (TEXT)
- created_at (TIMESTAMP)
```

#### user_presence
```sql
- user_id (UUID, PK, FK → users)
- is_online (BOOLEAN)
- last_seen (TIMESTAMPTZ)
```

#### notifications
```sql
- id (UUID, PK)
- user_id (UUID, FK → users)
- message (TEXT)
- is_read (BOOLEAN)
- related_request_id (UUID, FK → mentorship_requests)
- created_at (TIMESTAMPTZ)
```

### Database Triggers

#### 1. Update last_seen on presence change
```sql
CREATE TRIGGER trg_touch_last_seen
BEFORE UPDATE ON user_presence
FOR EACH ROW
WHEN (OLD.is_online IS DISTINCT FROM NEW.is_online)
EXECUTE FUNCTION touch_user_presence_last_seen()
```

#### 2. Auto-create notifications for friendships
```sql
CREATE TRIGGER trg_notify_friendship
AFTER INSERT OR UPDATE ON friendships
FOR EACH ROW
EXECUTE FUNCTION notify_on_friendship_change()
```
- Sends notification when friend request is sent
- Sends notification when friend request is accepted

---

## Implementation Analysis

### Strengths

1. **Comprehensive Feature Set**: The app covers a wide range of mentorship and social features
2. **Real-time Capabilities**: Effective use of Supabase channels for messaging
3. **Caching Strategy**: CacheService implementation reduces database load
4. **Responsive Design**: Media queries for small/large screens
5. **User Experience**: Loading states, error handling, pull-to-refresh, empty states
6. **Code Organization**: Clear separation of screens, widgets, and services
7. **Authentication Flow**: Robust auth state management with session persistence
8. **Analytics Dashboard**: Comprehensive mentor analytics with visual data

### Code Quality Issues

1. **Hardcoded Credentials in main.dart**:
```dart
await Supabase.initialize(
  url: 'https://pfmvutxsbthfvpacmixu.supabase.co',
  anonKey: 'eyJhbGci...' // Exposed API key
);
```
**⚠️ CRITICAL SECURITY ISSUE**: Credentials should be in `.env` file

2. **Inconsistent Error Handling**:
- Some screens use try-catch with user feedback
- Others silently fail or use `// ignore errors`
- No centralized error logging

3. **Debug Print Statements**:
```dart
print('DEBUG: Fetching posts for User ID: $userId');
```
Should use a proper logging framework in production

4. **No Loading State Management**:
- Multiple boolean flags (`_isLoading`, `_isSubmitting`, `_isProcessing`)
- Could benefit from a state management solution (Provider, Riverpod, Bloc)

5. **Commented Code**:
```dart
// password_hash TEXT NOT NULL,
```
Commented fields should be removed or properly documented

---

## Identified Issues & Faults

### Critical Issues

#### 1. Security: Exposed API Credentials
**File**: `main.dart:10-12`
**Issue**: Supabase URL and anon key are hardcoded
**Impact**: Security vulnerability, can't use environment-specific configs
**Fix**: Move to environment variables
```dart
url: Platform.environment['SUPABASE_URL']!,
anonKey: Platform.environment['SUPABASE_ANON_KEY']!,
```

#### 2. RLS Not Enabled on Posts Table
**File**: `schema.sql` (posts table)
**Issue**: No Row Level Security policies on posts table
**Impact**: All posts are fetched, then filtered client-side
**Code Evidence**: `home_feed_screen.dart:79-88`
```dart
// Comment: "RLS is disabled, so this gets everything"
final postsResponse = await _supabase.from('posts').select(...)
// Then client-side filtering at line 93
```
**Risk**:
- Performance issue (fetching unnecessary data)
- Potential security bypass if client-side filtering fails
**Fix**: Implement proper RLS policies on posts table

#### 3. Table Name Inconsistency
**File**: `002_create_user_interests.sql:2`
**Issue**: Migration creates `user_interests_supabase` but schema defines `user_interests`
**Impact**: Interest matching feature likely broken
**Evidence**:
- Schema: `user_interests` table with interest_id FK
- Migration: Creates `user_interests_supabase` with interest TEXT column
**Fix**: Standardize table name and schema

#### 4. Duplicate Columns in Posts Table
**File**: `schema.sql:105-106`, `003_create_post_comments.sql:20-22`
**Issue**: Posts table has both `user_id` and `author_id`
```sql
user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
author_id UUID REFERENCES users(id),
```
**Impact**:
- Confusion about which to use
- Data inconsistency risk
- Wasted storage
**Fix**: Remove one column (likely `user_id`), update all references

#### 5. Missing Column in post_media
**File**: Schema vs Code mismatch
**Schema**: `url` column
**Code** (`post_card.dart:271`): References `media_url`
```dart
media[0]['media_url'] ?? ''
```
**Impact**: Images won't display (null reference)
**Fix**: Standardize to either `url` or `media_url`

### Major Issues

#### 6. Missing Tables Referenced in Code
**File**: `mentor_dashboard_screen.dart:76-79, 97-100`
**Issue**: Code references tables not in schema:
- `conversations` table (line 76)
- `support_responses` table (line 97)
**Impact**: Analytics features will fail
**Fix**: Create missing tables or remove references

#### 7. Password Hash Field Commented Out
**File**: `schema.sql:17`
```sql
-- password_hash TEXT NOT NULL,
```
**Issue**: No password storage in users table
**Impact**: Supabase auth.users handles this, but creates confusion
**Fix**: Remove commented line or document why it's not needed

#### 8. Insecure RLS Policy in user_interests
**File**: `002_create_user_interests.sql:14-16`
```sql
CREATE POLICY "Anyone can view interests"
  ON user_interests_supabase FOR SELECT
  USING (true);
```
**Issue**: Using `USING (true)` defeats purpose of RLS
**Recommendation**: Should check authentication or implement privacy settings

#### 9. Category Filtering Not Implemented
**File**: `resources_feed_screen.dart:18, 112`
**Issue**: UI shows category filter, but:
- No `category` column in resources table
- Filter selection doesn't affect query
**Impact**: Non-functional UI element
**Fix**: Add category column and filtering logic

#### 10. Mood Field Not Used
**File**: `001_create_journal_entries.sql:7`, `vault_screen.dart`
**Issue**: Database has `mood` column, UI doesn't support it
**Impact**: Underutilized feature
**Enhancement**: Add mood selector in journal entry dialog

### Minor Issues

#### 11. Inconsistent Column Naming
- `post_media`: `url` vs `media_url`
- `post_media`: `mime_type` vs `media_type`
**Impact**: Developer confusion, potential runtime errors

#### 12. No Pagination
**Files**: `home_feed_screen.dart:88`, `resources_feed_screen.dart:36`
**Issue**:
- Posts: `.limit(50)`
- Resources: No limit
**Impact**: Performance degradation as data grows
**Fix**: Implement infinite scroll or pagination

#### 13. package.json in lib/ folder
**File**: `lib/package.json`
**Issue**: Next.js package.json in Flutter project
**Impact**: Confusing, indicates possible project structure issue
**Fix**: Remove or move to correct location

#### 14. Image Service Not Used
**File**: `lib/services/image_service.dart`
**Issue**: Service file exists but not imported/used anywhere
**Impact**: Dead code
**Action**: Either implement or remove

#### 15. Find People Popup Widget Unused
**File**: `lib/widgets/find_people_popup.dart`
**Issue**: Widget exists but never called
**Similar**: `add_post_popup.dart` likely unused (CreatePostScreen is used instead)
**Action**: Remove dead code

#### 16. Status Case Inconsistency
**File**: `mentor_dashboard_screen.dart:904`
```dart
onPressed: () => _handleRequest(request['id'], 'rejected'),
```
**Issue**: Uses lowercase 'rejected', but ENUM expects 'REJECTED'
**Impact**: Database constraint violation
**Fix**: Use uppercase 'REJECTED'

#### 17. Conversations Table Missing
**File**: `chat_screen.dart:56-84`
**Implementation**: Code builds conversations from messages table
**Issue**: No dedicated conversations table
**Impact**:
- Inefficient querying
- Can't store conversation metadata
- No group chat support
**Fix**: Create conversations table with participants

---

## Underutilization & Missing Features

### Defined But Not Implemented

1. **Mood Tracking in Vault**
   - Database: `journal_entries.mood` column exists
   - UI: No mood selector in entry dialog
   - Potential: Mood analytics, emotional wellness tracking

2. **Email Confirmation Flow**
   - Code checks `emailConfirmedAt` (auth_gate.dart:59)
   - No resend confirmation email UI
   - Impact: Users stuck if email not confirmed

3. **User Phone Numbers**
   - Database: `users.phone_number` column
   - UI: No phone input in signup or profile edit
   - Potential: SMS notifications, WhatsApp integration

4. **User Age & Gender**
   - Database: `users.age`, `users.gender` columns
   - Not captured during signup
   - Potential: Demographics analytics, age-appropriate matching

5. **Post Bookmarking**
   - UI: Bookmark icon in PostCard (line 328)
   - Functionality: `onPressed: () {}` (no implementation)
   - Missing: `bookmarks` table

6. **Post Sharing**
   - UI: Share icon in PostCard (line 316)
   - Functionality: No implementation
   - Missing: Share functionality (deep links, social sharing)

7. **Mentor Profession Filter**
   - Data: Available in `users.profession`
   - UI: No filter in mentees dashboard
   - Impact: Harder to find relevant mentors

### Partially Implemented Features

8. **Anonymous Messaging**
   - Database: `messages.is_anonymous` column
   - Code: Flag set to `false` (chat_screen.dart:20)
   - UI: No toggle to enable
   - Feature exists but not accessible

9. **Message Read Status**
   - Database: `messages.is_read` column
   - Code: No marking messages as read
   - UI: No read/unread indicator

10. **Resource Categories**
    - UI: Category filter chips (Career, Skills, Personal, Business)
    - Database: No category column
    - Filtering: Not functional

11. **Notifications Read Status**
    - Database: `notifications.is_read` column
    - UI: Popup shows unread count
    - Missing: Mark as read functionality

### Missing Core Features

12. **Search Functionality**
    - Users: No user search
    - Mentors: Only browse list, no search
    - Posts: No post search
    - Only implemented: Vault entries, Resources

13. **Edit/Delete Posts**
    - Users can create posts
    - No edit or delete functionality
    - Security risk: Can't remove inappropriate content

14. **Block/Report Users**
    - Friendships: BLOCKED status exists
    - No UI to block or report users
    - Missing: Content moderation tools

15. **Push Notifications**
    - Database: Rich notification system
    - App: No push notification integration
    - Impact: Users miss important updates

16. **Profile Pictures**
    - Database: `users.avatar_url` column
    - Signup: No avatar upload
    - Profile: Shows placeholder
    - Image service exists but unused

17. **Mentorship Progress Tracking**
    - Tables: `mentorships` table tracks relationships
    - Missing: Goals, milestones, session notes
    - Analytics: Only message counts, no qualitative data

18. **Video/Voice Calls**
    - Messaging exists
    - No video/voice call integration
    - Could integrate Agora, Twilio, or Jitsi

### UI/UX Improvements Needed

19. **No Dark Mode**
    - Code: Single theme in main.dart
    - User preference: Not supported

20. **No Offline Support**
    - All features require network
    - No local database (SQLite)
    - Cache is memory-only (lost on restart)

21. **No Data Export**
    - Vault: Private journals
    - No export to PDF/text
    - User data portability issue

22. **Limited Accessibility**
    - No semantic labels for screen readers
    - No font size adjustment
    - No high contrast mode

---

## Security Analysis

### Authentication
✅ **Good:**
- Email/password via Supabase auth
- Session persistence
- Email confirmation check
- Auth state listener

⚠️ **Issues:**
- Hardcoded credentials in code
- No refresh token handling explicitly shown
- No multi-factor authentication

### Authorization (RLS Policies)

**Properly Secured:**
- ✅ `journal_entries`: Users can only access own entries
- ✅ `post_comments`: Based on post visibility
- ✅ `post_likes`: No RLS needed (public actions)

**Insecure:**
- ❌ `posts`: No RLS, client-side filtering only
- ❌ `user_interests_supabase`: `USING (true)` allows anyone to read
- ❌ `messages`: No RLS defined in schema
- ❌ `friendships`: No RLS defined
- ❌ `mentorship_requests`: No RLS defined

**Missing Tables:**
- No RLS on `resources` (anyone can read)
- No RLS on `user_presence`
- No RLS on `notifications`

### Data Privacy
- ✅ Vault entries are properly isolated
- ⚠️ Post visibility implemented client-side (risky)
- ❌ No user data encryption at rest (Supabase default)
- ❌ No PII (Personally Identifiable Information) handling documented

### Input Validation
- ⚠️ Basic null checks in UI
- ❌ No server-side validation shown
- ❌ No SQL injection protection beyond Supabase's built-in
- ❌ No content filtering (profanity, spam)

### API Security
- ❌ Exposed anon key in source code
- ✅ Using anon key (not service role key) limits damage
- ⚠️ No rate limiting shown
- ⚠️ No request signing

---

## Recommendations

### Immediate Actions (Critical)

1. **Move credentials to environment variables**
   - Use `flutter_dotenv` package
   - Add `.env` to `.gitignore`
   - Update `main.dart` to read from environment

2. **Implement RLS on posts table**
   ```sql
   ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

   CREATE POLICY "Users can view public posts"
     ON posts FOR SELECT
     USING (visibility = 'PUBLIC');

   CREATE POLICY "Users can view own posts"
     ON posts FOR SELECT
     USING (auth.uid() = author_id);

   CREATE POLICY "Users can view friends posts"
     ON posts FOR SELECT
     USING (
       visibility = 'FRIENDS'
       AND EXISTS (
         SELECT 1 FROM friendships
         WHERE status = 'ACCEPTED'
         AND ((requester_id = auth.uid() AND addressee_id = author_id)
              OR (addressee_id = auth.uid() AND requester_id = author_id))
       )
     );
   ```

3. **Fix table name inconsistency**
   - Decide on `user_interests` or `user_interests_supabase`
   - Update all references
   - Create migration to rename table

4. **Remove duplicate author_id/user_id**
   - Pick one column (recommend `author_id`)
   - Update all queries
   - Drop unused column

5. **Fix status case mismatch**
   - Change 'rejected' to 'REJECTED' in mentor_dashboard_screen.dart:904

### Short-term (High Priority)

6. **Add missing RLS policies**
   - messages table
   - friendships table
   - mentorship_requests table
   - resources table (if needed)
   - notifications table

7. **Implement proper error handling**
   - Centralized error handler
   - User-friendly error messages
   - Error logging service (Sentry, Firebase Crashlytics)

8. **Remove dead code**
   - `lib/package.json`
   - Unused widgets (find_people_popup, add_post_popup)
   - Unused image_service.dart (or implement it)
   - Commented-out code in schema

9. **Fix missing tables**
   - Create `conversations` table for chat
   - Create `support_responses` table for anonymous support
   - Or remove code references if not needed

10. **Standardize column names**
    - Decide: `url` or `media_url`
    - Decide: `mime_type` or `media_type`
    - Update schema and code to match

### Medium-term (Feature Completion)

11. **Implement pagination**
    - Posts feed
    - Resources feed
    - Messages list
    - Use offset/limit or cursor-based pagination

12. **Complete partially implemented features**
    - Mood tracking in vault (add UI)
    - Anonymous messaging toggle
    - Message read status
    - Bookmark functionality
    - Share functionality
    - Resource categories (add column + filtering)

13. **Add post moderation**
    - Edit own posts
    - Delete own posts
    - Report posts
    - Admin moderation panel

14. **Implement user search**
    - Search users by name
    - Filter mentors by profession, district, interests
    - Full-text search in posts

15. **Profile completion**
    - Avatar upload during signup
    - Phone number collection
    - Age and gender (optional)
    - Bio/about section
    - Social links

### Long-term (Enhancements)

16. **State management upgrade**
    - Migrate from setState to Provider/Riverpod/Bloc
    - Centralized app state
    - Easier testing

17. **Push notifications**
    - Firebase Cloud Messaging integration
    - Notification preferences
    - In-app notification center

18. **Advanced features**
    - Video/voice calls
    - Screen sharing for mentorship sessions
    - Scheduled mentorship sessions
    - Calendar integration
    - Payment integration (for paid mentorship)

19. **Analytics & monitoring**
    - User behavior analytics (PostHog, Mixpanel)
    - Performance monitoring (Firebase Performance)
    - Crash reporting (Crashlytics)

20. **Accessibility improvements**
    - Screen reader support
    - High contrast mode
    - Font scaling
    - Keyboard navigation

21. **Offline support**
    - Local database (Drift, Hive, or Isar)
    - Sync mechanism
    - Offline queue for actions

22. **Testing**
    - Unit tests for services
    - Widget tests for UI components
    - Integration tests for critical flows
    - E2E tests with Patrol or integration_test

23. **Documentation**
    - API documentation
    - Component documentation
    - User manual
    - Developer onboarding guide

24. **Performance optimizations**
    - Image caching (cached_network_image)
    - Lazy loading
    - Tree shaking
    - Code splitting
    - Bundle size optimization

---

## Interface Analysis

### Screens Overview (21 screens)

1. **welcome_screen.dart** - Landing page with login/signup options
2. **login_screen.dart** - Email/password login
3. **signup_flow/signup_screen.dart** - Multi-step registration
4. **home_screen.dart** - Main navigation hub with bottom bar
5. **home_feed_screen.dart** - Social feed with posts
6. **profile_screen.dart** - User profile view
7. **edit_profile_screen.dart** - Profile editing
8. **mentor_dashboard_screen.dart** - Mentor analytics & requests
9. **mentees_dashboard_screen.dart** - Browse mentors
10. **vault_screen.dart** - Private journal
11. **chat_screen.dart** - Messaging interface
12. **messages_screen.dart** - Message list
13. **anonymous_chat_screen.dart** - Anonymous support chat
14. **anonymous_support_screen.dart** - Support hub
15. **resources_feed_screen.dart** - Educational resources
16. **resource_detail_screen.dart** - Resource full view
17. **create_post_screen.dart** - Post creation
18. **all_posts_screen.dart** - Full posts list
19. **interest_matching_screen.dart** - Interest-based matching
20. **friends_screen.dart** - Friends management
21. **notifications_screen.dart** - Notification center

### UI/UX Observations

**Strengths:**
- Consistent color scheme (primary: #6A5AE0 purple)
- Responsive design with screen size checks
- Loading states and empty states
- Pull-to-refresh gestures
- Smooth animations (like button scale animation)
- Material Design components

**Weaknesses:**
- No navigation drawer or app drawer
- Bottom navigation bar has 4-5 tabs (can be crowded)
- No breadcrumbs or back button indicators
- Some screens lack app bars
- Inconsistent use of AppMainBar vs TopAppBar
- No visual feedback for network errors
- Modal dialogs use basic AlertDialog (could be more polished)

### Widget Reusability

**Well-designed reusable widgets:**
- `PostCard` - Complex Instagram-style post with likes, comments, media
- `ResourceCard` - Resource preview card
- `AppMainBar` / `TopAppBar` - Consistent app bars
- `CommentsBottomSheet` - Modal comments view
- `NotificationIcon` - Badge icon with count

**Could be extracted:**
- Metric cards in mentor dashboard (repeated 4 times)
- User list tiles (mentors, mentees, conversations)
- Empty state placeholders (repeated pattern)
- Loading spinners
- Error widgets

---

## Conclusion

MkuluWanga is a **feature-rich mentorship platform** with solid foundations but several **critical issues** that need immediate attention:

### Critical Priorities:
1. **Security**: Remove hardcoded credentials, implement proper RLS
2. **Data Integrity**: Fix table/column name mismatches
3. **Functionality**: Create missing tables or remove broken references

### Overall Assessment:
- **Architecture**: 6/10 - Good structure but needs state management
- **Security**: 4/10 - Major RLS gaps and exposed credentials
- **Features**: 7/10 - Comprehensive but many partially implemented
- **Code Quality**: 6/10 - Good organization but inconsistent practices
- **UI/UX**: 7/10 - Clean design but missing polish
- **Database Design**: 5/10 - Good schema but execution issues

### Recommended Next Steps:
1. Fix all critical issues (security, RLS, table mismatches)
2. Complete partially implemented features
3. Add comprehensive testing
4. Implement proper state management
5. Add monitoring and analytics
6. Conduct security audit
7. Performance optimization
8. Accessibility improvements

**Estimated Effort to Production-Ready:**
- Critical fixes: 1-2 weeks
- Feature completion: 4-6 weeks
- Testing & optimization: 2-3 weeks
- **Total: 7-11 weeks** with a dedicated developer

---

**Document Version**: 1.0
**Last Updated**: 2025-10-07
**Total Dart Files Analyzed**: 36
**Lines of Code (approx)**: ~8,000+
**Database Tables**: 17+ tables
**Screens**: 21 screens
**Widgets**: 10+ reusable widgets
