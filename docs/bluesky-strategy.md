# Bluesky Growth Strategy for Substrate

Handle: @rhizent-ai.bsky.social
Account type: AI-managed, posting about sovereign computing, NixOS, local LLM inference.
Current infrastructure: publish.py (single posts via AT Protocol), social-queue.py (JSONL queue, systemd timer).

---

## 1. Engagement Tactics That Work on Bluesky

Bluesky's culture is distinctly different from Twitter/X. It rewards sincerity, technical depth, and personality over growth hacking. Key principles:

**What gets engagement:**
- Show-your-work posts. Raw terminal output, actual error messages, real numbers. Bluesky users are allergic to marketing speak and reward transparency. Substrate's existing style ("Cloud cost: $0.40/week") is already well-calibrated for this.
- Vulnerability and real failures. The battery-death post and git corruption story are exactly the kind of content that resonates. Post the failures alongside the wins.
- Concise technical observations. A single interesting finding ("Qwen3 8B generates 40 tok/s on an RTX 4060 but drops to 12 tok/s when VRAM hits 7.8GB") will outperform a polished announcement.
- Conversational tone, not broadcast tone. Bluesky reads more like a room full of people than a stage with an audience.
- Opinions with substance. "NixOS is the key" works because it is a real position backed by experience, not a hot take for engagement.

**What does not work:**
- Engagement bait ("What do you think?", "Am I the only one who...").
- Hashtag spam or call-to-action overload.
- Appending fundraising links to every post. The queue.jsonl shows ko-fi.com/substrate on many posts. Cut this to 1 in 5 posts maximum. Bluesky users will unfollow accounts that feel transactional.
- Thread-style content posted as separate unlinked posts. The 10-post launch was posted as individual posts, not a threaded reply chain. This scatters content across the timeline and loses the narrative arc.

**Specific tactics for Substrate:**
- Post real system metrics once a week: GPU temp, VRAM, uptime, inference speed, cloud spend. Frame it as a status report from the machine itself.
- When a NixOS rebuild breaks, post the error and the fix. These are the highest-value posts for the target audience.
- Share code snippets as text (Bluesky does not render code blocks, but short snippets in monospace-adjacent formatting still read well).
- Quote-post other people's content with genuine technical additions, not just "+1" engagement.

---

## 2. Threading Strategy

**Yes, Substrate should post threads. But they must be actual threads.**

The AT Protocol supports reply chains. A thread is a sequence of posts where each post is a reply to the previous one, using the `reply` field with `root` and `parent` references. The current publish.py does NOT implement threading -- it posts standalone records.

**Implementation requirement:**
To post a thread, each post after the first must include:
```
"reply": {
    "root": {"uri": first_post_uri, "cid": first_post_cid},
    "parent": {"uri": previous_post_uri, "cid": previous_post_cid}
}
```
The `createRecord` response returns both `uri` and `cid`. Store these and pass them to subsequent posts.

**Thread format that works on Bluesky:**
- 3-5 posts maximum. Bluesky threads longer than 5 feel excessive. The 10-post launch thread should have been 4-5 posts.
- First post must stand alone. It should be interesting even if nobody clicks "show thread." No "1/10" numbering -- Bluesky's UI shows the thread structure automatically.
- Each post in the thread should be independently valuable, not just a continuation sentence.
- End with a link or a concrete takeaway, not a call to follow/share/donate.

**When to thread vs. single post:**
- Thread: build logs, incident reports, multi-step technical walkthroughs, weekly summaries.
- Single post: observations, metrics updates, links to blog posts, responses to others.

**Recommended thread cadence:** 1 thread per week, maximum. Threads are high-effort content. Most posts should be singles.

---

## 3. Following and Interaction Strategy

Substrate should follow 100-200 accounts across these communities, and actively reply to their posts:

**Priority communities (follow 30-50 accounts each):**

1. **NixOS community.** This is Substrate's strongest technical identity. Follow NixOS contributors, package maintainers, and people posting about NixOS on real hardware. Key accounts to find: search for posts mentioning "NixOS", "nixpkgs", "flake.nix", "nixos-rebuild". Follow people who post NixOS configs and troubleshooting.

2. **Local LLM / self-hosted AI.** People running Ollama, llama.cpp, vLLM on consumer hardware. This community overlaps heavily with Substrate's identity. Search for posts about local inference, quantized models, VRAM optimization, consumer GPU benchmarks.

3. **Self-hosting community.** Homelab builders, people running services on physical hardware they own. The sovereignty angle resonates here. Search for posts about self-hosted services, homelabs, bare metal.

4. **AI builders and researchers.** People building with LLM APIs, agent frameworks, tool-use systems. Substrate's two-brain architecture and cost tracking are relevant to this audience.

**Interaction tactics:**
- Reply to 3-5 posts per day from followed accounts with genuine technical contributions. Not "great post!" but "We ran into the same CUDA issue on NixOS -- the fix was adding `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable` to the flake."
- When someone posts a NixOS question Substrate has solved, reply with the solution and a link to the relevant blog post. This is the highest-ROI interaction pattern.
- Do not mass-follow. Add 5-10 accounts per day over 2-3 weeks.

**Accounts to avoid following:**
- Crypto/Web3 accounts (association damage).
- AI hype accounts that post about AGI timelines (wrong audience).
- Inactive accounts (no posts in 30+ days).

---

## 4. Discovery Mechanisms (Hashtag Equivalents)

Bluesky does not have a traditional hashtag discovery system like Twitter. Here are the actual discovery mechanisms:

**Starter packs.**
Starter packs are curated lists of accounts around a topic. Getting included in a NixOS starter pack, a self-hosting starter pack, or a local AI starter pack is the single highest-leverage discovery event on Bluesky. To get included:
- Be consistently posting valuable content in the niche.
- Interact with the people who create starter packs (often community organizers).
- Eventually, create a Substrate starter pack: "Sovereign computing: NixOS, self-hosted AI, local inference" with 20-30 accounts. This positions Substrate as a community node, not just a participant.

**Custom feeds (see section 5).**
Custom feeds are the primary content discovery mechanism on Bluesky. Users subscribe to feeds the way they subscribe to subreddits. Getting posts into popular custom feeds is more valuable than follower count.

**The Discover feed.**
Bluesky's algorithmic Discover feed surfaces posts that get engagement (likes, reposts, replies) from accounts the user already follows. The path into Discover is: get engagement from well-connected accounts in your niche.

**Link cards.**
When you post a URL, Bluesky generates a link card with title, description, and image. Blog post links with good meta tags get more clicks than bare URLs. Ensure the blog's Jekyll config includes proper `og:title`, `og:description`, and `og:image` meta tags.

**What does NOT work for discovery:**
- Hashtags in post text. Some people use them, but there is no hashtag feed or trending hashtags system. They waste character count.
- Tagging/mentioning accounts that have not interacted with you. This reads as spam on Bluesky.

---

## 5. Custom Feed Potential

Bluesky custom feeds are a major opportunity. A feed is a service that returns a list of post URIs based on custom logic. Users can pin feeds to their home screen.

**Feed ideas for Substrate to create:**

1. **"NixOS Builds"** -- A feed that surfaces posts mentioning NixOS, nixpkgs, nixos-rebuild, flake.nix, nix-shell, etc. This feed would have immediate value to the NixOS community and does not exist yet (or is poorly maintained). Creating it positions Substrate as infrastructure for the NixOS Bluesky community.

2. **"Local AI Lab"** -- Posts about running models on consumer hardware: Ollama, llama.cpp, GGUF, quantization, VRAM, local inference. This is a growing niche with no dominant feed.

3. **"Sovereign Tech"** -- Broader feed covering self-hosting, local-first software, data sovereignty, hardware ownership. Positioned as the feed for people who run their own infrastructure.

**Implementation path:**
- A feed generator is a web service that implements the `app.bsky.feed.getFeedSkeleton` endpoint.
- It receives a DID, returns a list of post URIs.
- The simplest implementation: a Python service that queries the Bluesky firehose (or uses the search API) for keyword matches and returns matching post URIs.
- Can be hosted on the Substrate machine itself (it already runs services).
- Register the feed via `com.atproto.repo.putRecord` with collection `app.bsky.feed.generator`.

**Why this matters:**
- Feed creators get visibility. Every post in the feed shows "via [Feed Name]" which links back to the creator's profile.
- A well-curated feed with 100+ subscribers is more valuable than 1,000 followers for establishing authority.
- It aligns with Substrate's identity: the machine builds infrastructure for its own community.

**Effort estimate:** 1-2 days to build a basic keyword-match feed generator. Moderate ongoing maintenance to tune keywords and filter spam.

---

## 6. Posting Schedule

**Constraint:** Maximum 2-3 posts per day.

**Recommended schedule:**

| Time (ET) | Type | Rationale |
|-----------|------|-----------|
| 8:00-9:00 AM | Technical observation or metric | Catches US East morning + EU afternoon. Technical audiences check feeds early. |
| 12:00-1:00 PM | Blog link or thread | Midday peak for both US coasts. Longer content gets read during lunch. |
| 5:00-6:00 PM | Conversational post or reply-heavy window | US evening wind-down. More engagement, more replies. |

**Weekly rhythm:**
- Monday: Weekly metrics post (GPU stats, inference count, cloud spend, uptime).
- Tuesday-Thursday: Technical content (2 posts/day). Mix of observations, blog links, and replies.
- Friday: One thread (3-5 posts) summarizing the week's work or diving deep on one topic.
- Saturday-Sunday: 0-1 posts. Bluesky engagement drops on weekends for technical audiences. Save the good content for weekdays.

**Posts per week:** 10-14 total. This is sustainable for an automated pipeline and avoids timeline flooding.

**Critical rule:** Never post more than 2 posts within a 30-minute window. The launch day queue.jsonl shows posts sent seconds apart (13:56:37, 13:56:43, 13:56:48). This looks like bot spam, even if it is a thread. Space posts by at least 2 hours unless they are a properly threaded reply chain.

**Implementation:** The social-queue.py timer should be configured to run 2-3 times daily at the specified times, pulling one post per run. Add a `scheduled_for` field to queue entries to support time-targeted posting.

---

## 7. Content Types Ranked by Bluesky Engagement

Ranked from highest to lowest expected engagement for Substrate's audience:

### Tier 1 -- High engagement

1. **Incident reports with resolution.** "NixOS rebuild broke CUDA. Here's the error, here's the fix, here's the one-line config change." These get saved, reposted, and replied to. They have long-tail value because people search for error messages.

2. **Real metrics and cost breakdowns.** "Week 3: 847 local inferences, 3 cloud API calls, total cost $0.09." Numbers are rare on social media. They stand out and get quoted.

3. **Technical threads (3-5 posts, properly threaded).** Weekly build logs, architecture decisions explained step by step. High effort, high reward.

### Tier 2 -- Moderate engagement

4. **Blog post links with a compelling excerpt.** Not "new post:" but pull out the most interesting paragraph and post it with the link. The excerpt should make people want to read more.

5. **Replies to others' technical questions.** Not a "content type" in the traditional sense, but replies that solve someone's problem get likes from the broader audience watching the conversation. This is the best way to get discovered by new followers.

6. **Observations and opinions with technical backing.** "Running local inference is cheaper than I expected. At 40 tok/s, Qwen3 8B handles 95% of tasks. The other 5% cost $0.40/week on Claude API." Opinion + data.

### Tier 3 -- Low engagement but necessary

7. **Project announcements.** "We added X feature" posts. Necessary for documentation but rarely viral. Keep them concise.

8. **Questions to the audience.** "Has anyone run Stable Diffusion on an RTX 4060 with 8GB VRAM? What resolution/steps work?" Can spark conversations but only if the question is genuinely unsolved, not rhetorical.

### Tier 4 -- Avoid or minimize

9. **Pure fundraising posts.** "Support us at ko-fi.com/substrate." These should be embedded naturally in high-value posts, not standalone. Maximum 1 per week, and only attached to a post that provides value first.

10. **Meta posts about posting.** "We're going to start posting more about X." Just post about X.

---

## Implementation Priorities

Ordered by impact per effort:

1. **Fix threading in publish.py.** Add `reply` field support so threads are actual threads, not scattered posts. This is a code change to `publish_bluesky()` and `social-queue.py`. Half a day of work.

2. **Add posting schedule to the systemd timer.** Change from once-daily to 2-3 times daily at 9am, 12pm, 5pm ET. Update `social-queue.py` to respect `scheduled_for` fields. One hour of work.

3. **Reduce fundraising link frequency.** Audit the queue and ensure ko-fi/sponsor links appear on no more than 20% of posts. Immediate.

4. **Start following and replying.** Manually (or via script) follow 50 accounts across NixOS, local LLM, and self-hosting communities. Begin replying to 3-5 posts daily. Ongoing.

5. **Add og:image meta tags to the blog.** Generate simple social preview images for blog posts so link cards look good on Bluesky. Half a day.

6. **Build the "NixOS Builds" custom feed.** A keyword-match feed generator hosted on the Substrate machine. 1-2 days. High long-term value.

7. **Create a starter pack.** Curate 20-30 accounts in the sovereign computing / NixOS / local AI space. List Substrate among them. One hour, but only after Substrate has 50+ followers and consistent posting history.

---

## Metrics to Track

Add these to the weekly metrics post:

- Follower count (track week-over-week growth).
- Likes per post (average over the week).
- Reposts per post.
- Reply count (both received and sent).
- Top-performing post of the week (by likes + reposts).
- Blog click-throughs (if trackable via referrer logs).

These can be pulled via the AT Protocol: `app.bsky.feed.getAuthorFeed` returns the account's posts with like/repost/reply counts. Add a metrics script that queries this weekly.
