set dotenv-load

[doc("Run the website locally with all draft posts")]
run:
    hugo server --buildDrafts

[doc("Build the website")]
build:
    hugo

[doc("Remove generated artefacts")]
clean:
    rm -rf ./public

[doc("Deploy the website to the test instance")]
deploy-test: clean
    hugo -D --baseURL $SWA_PREVIEW_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env preview

[doc("Deploy the website to the live instance")]
deploy-live: clean
    hugo --baseURL $SWA_LIVE_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env Production

[doc("Update robots.txt to disallow AI crawlers")]
update-robots:
    rm ./layouts/robots.txt

    curl -X POST https://api.darkvisitors.com/robots-txts \
        -H "Authorization: Bearer ${DV_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{ "disallow": "/", "agent_types": [ "AI Data Scraper", "AI Assistant", "AI Search Crawler", "Undocumented AI Agent" ] }' \
        > ./layouts/robots.txt
