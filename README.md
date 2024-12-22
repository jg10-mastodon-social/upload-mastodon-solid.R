# Upload Mastodon outbox to Solid pod

⚠️ Hardcoded for https://jg10.solidcommunity.net/devlog/home.html#mastodon

Downloads outbox pages, starting from the last and following `as:prev` links.

- Uploads to Solid pod
- Adds `rdfs:sameAs` links to an index
- Redirects index to first page
- Redirects `max_id` pages to `min_id` pages
- Suppresses prev and next for first and last page 

Also see https://jg10.solidcommunity.net/devlog/home.html#activitypub
