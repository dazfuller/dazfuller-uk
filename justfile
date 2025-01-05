set dotenv-load

run:
    hugo server --buildDrafts

build:
    hugo

clean:
    rm -rf ./public

deploy-test: clean
    hugo -D --baseURL $SWA_PREVIEW_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env preview

deploy-live: clean
    hugo --baseURL $SWA_LIVE_NAME
    swa deploy -a ./ -d $SWA_TOKEN -O ./public --env Production

update-robots:
    rm ./layouts/robots.txt

    curl -X POST https://api.darkvisitors.com/robots-txts \
        -H "Authorization: Bearer ${DV_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{ "disallow": "/", "agent_types": [ "AI Data Scraper", "AI Assistant", "AI Search Crawler", "Undocumented AI Agent" ] }' \
        > ./layouts/robots.txt
