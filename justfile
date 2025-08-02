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

[doc("Deploy to SFTP location")]
deploy: clean build
    lftp -c "open sftp://$FTP_USER:$FTP_PASS@$FTP_HOST; mirror --reverse --parallel=10 public public_html"

[doc("Create a backup of the current site")]
backup:
    lftp -c "open sftp://$FTP_USER:$FTP_PASS@$FTP_HOST; mirror --delete --parallel=10 public_html site_backup"

[doc("Update robots.txt to disallow AI crawlers")]
update-robots:
    rm ./layouts/robots.txt

    curl -X POST https://api.darkvisitors.com/robots-txts \
        -H "Authorization: Bearer ${DV_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{ "disallow": "/", "agent_types": [ "AI Data Scraper", "AI Assistant", "AI Search Crawler", "Undocumented AI Agent" ] }' \
        > ./layouts/robots.txt
