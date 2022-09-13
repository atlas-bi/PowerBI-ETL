<h1 align="center">PowerBI ETL</h1>
<h4 align="center">Atlas BI Library ETL | PowerBI</h4>

<p align="center">
 <a href="https://www.atlas.bi" target="_blank">Website</a> • <a href="https://demo.atlas.bi" target="_blank">Demo</a> • <a href="https://www.atlas.bi/docs/bi-library/" target="_blank">Documentation</a> • <a href="https://discord.gg/hdz2cpygQD" target="_blank">Chat</a>
</p>

<p align="center">
 <a href="https://discord.gg/hdz2cpygQD"><img alt="discord chat" src="https://badgen.net/discord/online-members/hdz2cpygQD/" /></a>
 <a href="https://github.com/atlas-bi/Solr-Search-ETL/releases"><img alt="latest release" src="https://badgen.net/github/release/atlas-bi/Solr-Search-ETL" /></a>

<p align="center">Load PowerBI metadata into the Atlas database.
 </p>

## 🏃 Getting Started

This is a user contributed ETL that can be used with the [Atlas Metadata ETL](https://github.com/atlas-bi/atlas-bi-library-etl).

It is specifically made to use a cloud PowerBI.

The SSIS package in `/etl` can be added in with the other ETL SSIS packages in Visual Studio. The SISS package will run various powershell scripts which are in the `/powershell` folder. See the `notes.txt` and `/modified_sql` to see modifications you may need to make for this ETL to work with your PowerBI install.

## 🎁 Contributing

This repository uses commitzen. Please commit `npm run commit && git push`.
