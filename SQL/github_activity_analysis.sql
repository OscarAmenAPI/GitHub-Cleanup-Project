-- 1. Total Repositories
SELECT
	COUNT(DISTINCT repo_id) AS total_repositories
FROM fullday

-- 2. Unique Repository Owners
SELECT
    COUNT(
        DISTINCT LEFT(
            repo_name,
            CHARINDEX('/', repo_name) - 1
        )
    ) AS unique_repository_owners
FROM fullday
WHERE repo_name LIKE '%/%';

-- 3. Most common event types
SELECT
	event_type,
	COUNT(*) AS total_events
FROM fullday
GROUP BY event_type
ORDER BY total_events DESC

-- 4. Total events for the day
SELECT
	COUNT(event_type) AS total_events
FROM fullday

-- 5. Unique user generating activity
SELECT
	COUNT(DISTINCT actor_id) AS unique_users
FROM fullday
WHERE event_type IS NOT NULL

-- 6. Unique repositories received activity
SELECT
	COUNT(DISTINCT repo_id) AS unique_repositories
FROM fullday
WHERE event_type IS NOT NULL

-- 7. Repositories with most activity
SELECT TOP 10
	repo_name,
	COUNT(event_type) AS total_events
FROM fullday
GROUP BY repo_name
ORDER BY total_events DESC

-- 8. User with most events
SELECT TOP 10
	actor_login,
	COUNT(event_type) AS total_events
FROM fullday
GROUP BY actor_login
ORDER BY total_events DESC

-- 9. Total Activity by Hour
SELECT
	DATEPART(HOUR, created_at) AS hourOfDay,

	COUNT(event_type) AS total_events,

	RANK() OVER(
	ORDER BY COUNT(event_type) DESC
	) hour_ranked

FROM fullday
GROUP BY DATEPART(HOUR, created_at)
ORDER BY hourOfDay DESC

-- 10. Repository with the most unique customer contributors
SELECT TOP 10
	repo_name,
	COUNT(DISTINCT actor_id) AS unique_contributors
FROM fullday
WHERE event_type IN (
	'PushEvent',
	'CommitCommentEvent',
    'IssueCommentEvent',
    'IssuesEvent',
    'PullRequestEvent',
    'PullRequestReviewCommentEvent',
    'PullRequestReviewEvent',
    'ReleaseEvent'
)
GROUP BY repo_name
ORDER BY unique_contributors DESC

-- 11. Users with the most contribution events overall
WITH ContributorActivity AS
(
    SELECT
        repo_name,
        actor_login,
        COUNT(*) AS total_contributions
    FROM fullday
    WHERE event_type IN
    (
        'PushEvent',
        'CommitCommentEvent',
        'IssueCommentEvent',
        'IssuesEvent',
        'PullRequestEvent',
        'PullRequestReviewCommentEvent',
        'PullRequestReviewEvent',
        'ReleaseEvent'
    )
    GROUP BY
        repo_name,
        actor_login
),
RankedContributors AS
(
    SELECT
        repo_name,
        actor_login,
        total_contributions,
        RANK() OVER
        (
            PARTITION BY repo_name
            ORDER BY total_contributions DESC
        ) AS contributor_rank
    FROM ContributorActivity
)
SELECT
    repo_name,
    actor_login,
    total_contributions
FROM RankedContributors
WHERE contributor_rank = 1
ORDER BY total_contributions DESC;

-- 12. Repository ranks by unique contributors and total event activity
WITH repo_metrics AS
(
    SELECT
        repo_name,
        COUNT(*) AS development_events,
        COUNT(DISTINCT actor_id) AS unique_contributors
    FROM fullday
    WHERE event_type IN
    (
        'PushEvent',
        'CommitCommentEvent',
        'IssueCommentEvent',
        'IssuesEvent',
        'PullRequestEvent',
        'PullRequestReviewCommentEvent',
        'PullRequestReviewEvent',
        'ReleaseEvent'
    )
    AND repo_name IS NOT NULL
    GROUP BY repo_name
),
ranked AS
(
    SELECT
        repo_name,
        development_events,
        unique_contributors,

        DENSE_RANK() OVER
        (
            ORDER BY development_events DESC
        ) AS activity_rank,

        DENSE_RANK() OVER
        (
            ORDER BY unique_contributors DESC
        ) AS contributor_rank,

        ROUND(
            development_events * 1.0 /
            NULLIF(unique_contributors, 0),
            2
        ) AS events_per_contributor
    FROM repo_metrics
)
SELECT TOP 25
    repo_name,
    development_events,
    unique_contributors,
    activity_rank,
    contributor_rank,
    events_per_contributor,

    contributor_rank - activity_rank AS rank_difference
FROM ranked
ORDER BY activity_rank;
