<details><summary>Thinking</summary>

I need to create a more descriptive document in English that explains the flow of each use case, focusing on:
- Who initiates what request
- How data flows between components
- The sequence of events for each interaction

This should be a higher-level document that helps contributors understand the system design without diving into implementation details too much.

</details>

# Kahoot Clone System Design Document

## Overview

This document describes the architecture and workflows of our Kahoot clone application, focusing on how data and requests flow through the system. It serves as a reference for all contributors to ensure a shared understanding of system behavior.

## System Architecture

Our system uses:
- **Frontend**: React application hosted on Cloudflare Pages
- **Database**: Supabase PostgreSQL for data storage and business logic
- **Real-time Communication**: Supabase Realtime for live updates between clients
- **Serverless Functions**: Supabase Edge Functions for operations that cannot be handled in PostgreSQL
- **Authentication**: Supabase Auth for user management

## Data Flow Patterns

### Client-Server Communication

**Direct Database Access**:
- Frontend clients connect directly to Supabase using Row-Level Security (RLS) policies
- Most CRUD operations happen via direct database queries with appropriate permissions

**Real-time Updates**:
- PostgreSQL triggers notify clients of relevant changes through Supabase Realtime channels
- Clients subscribe to these channels to receive updates without polling

**Edge Functions**:
- Used for more complex operations that require additional processing beyond what PostgreSQL can handle

## Use Cases

### 1. User Management

#### Creating an Account / Logging In

**Workflow**:
1. **User** initiates login or signup through the frontend UI
2. **Frontend** uses Supabase Auth UI components to handle the authentication flow
3. **Supabase Auth** processes the credentials and returns authentication tokens
4. **Frontend** stores these tokens locally and redirects to the dashboard

**Data Flow**:
- User credentials → Frontend → Supabase Auth → Frontend (tokens)
- User data is stored in Supabase's ```auth.users``` table

#### Viewing Quiz Library

**Workflow**:
1. **User** navigates to the library view
2. **Frontend** sends a query to Supabase requesting all quizzes owned by the current user
3. **Database** checks RLS policies and returns only quizzes owned by the user
4. **Frontend** displays the quizzes in a grid or list format

**Data Flow**:
- Request (user ID) → Database (filters by user ID) → Frontend (quiz data)
- Optional sorting/filtering happens at the database level

### 2. Editing a Quiz

#### Creating/Updating Quiz Content

**Workflow**:
1. **User** opens the quiz editor and makes changes to quiz content
2. **Frontend** sends individual update operations as the user edits:
   - Quiz metadata updates (title, description)
   - Question additions, modifications, or deletions
   - Answer option changes
3. **Database** processes these requests through RLS policies, ensuring users can only modify their own quizzes
4. **Frontend** provides immediate feedback by updating the UI

**Data Flow**:
- Quiz metadata: Frontend → Database (update quizzes table)
- Questions: Frontend → Database (insert/update/delete in questions table)
- Answer options: Frontend → Database (insert/update/delete in answer_options table)

#### Saving Quiz Changes

**Workflow**:
1. **User** triggers a save operation (or autosave occurs)
2. **Frontend** sends any remaining unsaved changes to the database
3. **Database** updates the ```updated_at``` timestamp
4. **Frontend** confirms successful save to the user

**Data Flow**:
- Batch of changes → Database → Confirmation response → UI update

### 3. Running a Quiz

#### Starting a Room

**Workflow**:
1. **Host** selects a quiz and initiates a game session
2. **Frontend** calls the PostgreSQL function ```create_game_session```
3. **Database**:
   - Generates a unique 6-character join code
   - Creates a record in the ```game_sessions``` table with status 'waiting'
   - Returns the session ID and join code
4. **Frontend** displays the join code and a waiting screen for the host

**Data Flow**:
- Quiz ID → ```create_game_session``` function → Session data (ID, join code) → Host UI

#### Joining a Room

**Workflow**:
1. **Player** enters the join code and nickname
2. **Frontend** calls the PostgreSQL function ```join_game_session```
3. **Database**:
   - Validates the join code against active waiting sessions
   - Creates a record in the ```players``` table
   - Triggers a notification through PostgreSQL trigger ```notify_player_joined```
4. **Host's Frontend** receives the join notification through Supabase Realtime
5. **Host's UI** updates to show the new player
6. **Player's Frontend** shows a waiting screen

**Data Flow**:
- Join code, nickname → ```join_game_session``` function → Player ID → Player UI
- PostgreSQL trigger → Supabase Realtime channel → Host UI update

#### Starting a Question

**Workflow**:
1. **Host** initiates the game or advances to the next question
2. **Frontend** calls the appropriate PostgreSQL function:
   - ```start_game``` (first question)
   - ```next_question``` (subsequent questions)
3. **Database**:
   - Updates the game session status to 'active'
   - Sets the current question ID
   - Triggers notification through PostgreSQL trigger ```notify_game_status_changed```
4. **All Frontends** (host and players) receive the status update via Supabase Realtime
5. **Host UI** shows the question, answer options, and timer
6. **Player UIs** show the question and answer options for selection

**Data Flow**:
- Host action → Database function → Game state update → PostgreSQL trigger → Realtime update to all clients

#### Answering a Question

**Workflow**:
1. **Player** selects an answer option
2. **Frontend** records the selection time and calls the ```submit_answer``` function
3. **Database**:
   - Records the answer in the ```player_answers``` table
   - Calculates the score based on correctness and response time
   - Updates the player's total score
   - Triggers notification through a PostgreSQL trigger
4. **Host UI** receives the answer notification and updates the answer statistics
5. **Player UI** switches to "waiting for results" state

**Data Flow**:
- Player selection, response time → ```submit_answer``` function → Score calculation → Database update
- PostgreSQL trigger → Realtime update → Host UI statistics update

#### Seeing the Results

**Workflow**:
1. **Host** advances to results after time expires or all players answer
2. **Database** aggregates answer data and calculates statistics
3. **Frontend** queries for question results:
   - Distribution of answers
   - Correct answer information
   - Top performers for this question
4. **All UIs** update to show:
   - **Host**: Comprehensive statistics and leaderboard
   - **Players**: Whether their answer was correct and their current score

**Data Flow**:
- Time expiration → Database query for results → Results data → All UIs
- PostgreSQL trigger → Realtime update → All clients show results view

#### Game Completion

**Workflow**:
1. **Host** advances past the final question
2. **Frontend** calls the ```next_question``` function which detects no more questions exist
3. **Database** sets the game session status to 'completed'
4. **All UIs** transition to the final results screen
5. **Database** provides final leaderboard data ordered by score

**Data Flow**:
- Final question completion → Database update → Game end notification → All UIs show final results

## Real-time Communication Details

### Channel Structure

- **Game Session Channel**: ```game:{session_id}```
  - Updates to game state
  - Current question transitions
  
- **Player Channel**: ```player:{player_id}```
  - Player-specific updates
  - Score changes

- **Answer Channel**: ```answers:{session_id}```
  - Aggregated answer submissions data
  - Answer statistics updates

### PostgreSQL Triggers

1. **Player Joined Trigger**:
   - Fires when a new player joins
   - Notifies host to update player list

2. **Game Status Changed Trigger**:
   - Fires when game state changes
   - Notifies all clients to update their UI

3. **Answer Submitted Trigger**:
   - Fires when a player submits an answer
   - Updates host UI with answer statistics

## Database Security

All database access is controlled through Row-Level Security policies:

- **Quiz Ownership**: Users can only view, edit, and start games with quizzes they own
- **Game Session Control**: Only the host can manage the game state of sessions they created
- **Player Actions**: Players can only submit answers for their own player ID and active questions

## Challenges and Solutions

### Handling Concurrent Player Actions

- **Challenge**: Multiple players answering simultaneously
- **Solution**: PostgreSQL transactions ensure data integrity during score calculations

### Real-time Synchronization

- **Challenge**: Keeping all clients in sync with game state
- **Solution**: Supabase Realtime channels with PostgreSQL triggers provide immediate updates to all connected clients

### Score Calculation Logic

- **Challenge**: Fair scoring based on speed and correctness
- **Solution**: Implemented in the ```submit_answer``` function directly in PostgreSQL to ensure consistent calculations

## Technical Dependencies

- Supabase project with PostgreSQL database
- Supabase Auth enabled
- Supabase Realtime service activated
- React frontend deployed to Cloudflare Pages
- RLS policies properly configured for security

This document outlines the core workflows and data flows of our Kahoot clone application. All contributors should reference this document to understand how user actions translate to system behavior and data movement.

