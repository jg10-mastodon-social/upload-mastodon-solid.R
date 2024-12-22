library(solidR)
library(httr2)
library(rdflib)
library(redland)

client <- solid_client_register_dyn("https://solidcommunity.net")

store <- rdf()
urls <- "https://mastodon.social/users/jg10/outbox?min_id=0&page=true"
repeat {
  url <- urls[1]
  body <- request(url) %>%
    req_perform() %>%
    resp_body_string()

  rdf_parse(body, format = "jsonld", rdf = store)

  solidurl <- sub(
    ".*min_id=(.*)&.*",
    "https://jg10.solidcommunity.net/devlog/outbox-min_id-\\1.jsonld",
    url
  )
  print(solidurl)


  tryCatch(
    request(solidurl) %>%
      req_method("HEAD") %>%
      req_oauth_solid_dpop(client) %>%
      req_perform() %>%
      resp_status() %>%
      print(),
    httr2_http_404 = function(cnd) {
      request(solidurl) %>%
        req_method("PUT") %>%
        req_body_raw(body, type = "application/ld+json") %>%
        req_oauth_solid_dpop(client) %>%
        req_perform()
    }
  )

  pages <- rdf_query(store, "
  PREFIX as: <https://www.w3.org/ns/activitystreams#>
  SELECT ?page ?prev ?next
  where {
	  ?page as:partOf <https://mastodon.social/users/jg10/outbox>.
	  OPTIONAL {?page as:next ?next.}
	  OPTIONAl {?page as:prev ?prev.}
  }
	  ")
  urls <- pages$prev[!pages$prev %in% pages$page]
  urls <- na.omit(urls)
  if (length(urls) == 0) break
  if (url == urls[1]) break
}
pages

# Link to local copy
solidurl <- sub(
  ".*min_id=(.*)&.*",
  "https://jg10.solidcommunity.net/devlog/outbox-min_id-\\1.jsonld",
  pages$page
)
solidurl <- sprintf(
  "<%s> rdfs:seeAlso <%s>. ",
  pages$page,
  solidurl
) %>% paste0(collapse = "")

# Link max_id pages to corresponding min_id page
nextlinks <- merge(pages, pages, by.x = "page", by.y = "prev")
nextlinks <- nextlinks[!is.na(nextlinks$next.x), ]
nextlinks <- sprintf(
  "<%s> lin:redirectTemporary <%s>. ",
  nextlinks$next.x,
  nextlinks$page.y
) %>% paste0(collapse = "")

body <- sprintf("
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix lin: <https://purl.org/pdsinterop/link-metadata#>.

:x a solid:InsertDeletePatch;
solid:inserts {
%s
%s
}.", solidurl, nextlinks)

# Link to first page to open
request("https://jg10.solidcommunity.net/devlog/mastodon") %>%
  req_method("PATCH") %>%
  req_body_raw(body, type = "text/n3") %>%
  req_oauth_solid_dpop(client) %>%
  req_perform()

body <- sprintf('
@prefix solid: <http://www.w3.org/ns/solid/terms#>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix lin: <https://purl.org/pdsinterop/link-metadata#>.

:x a solid:InsertDeletePatch;
solid:where {
<https://jg10.solidcommunity.net/devlog/mastodon> lin:redirectTemporary ?first.
};
solid:deletes {
<https://jg10.solidcommunity.net/devlog/mastodon> lin:redirectTemporary ?first.
?first <https://jg10.solidcommunity.net/devlog/mastodon#first> "true".
};
solid:inserts {
<https://jg10.solidcommunity.net/devlog/mastodon> lin:redirectTemporary <%s>.
<%s> <https://jg10.solidcommunity.net/devlog/mastodon#first> "true".
}.', pages$page[3], pages$page[3])


request("https://jg10.solidcommunity.net/devlog/mastodon") %>%
  req_method("PATCH") %>%
  req_body_raw(body, type = "text/n3") %>%
  req_oauth_solid_dpop(client) %>%
  req_perform()
