# confluence-cloud-vim

confluence-cloud-vim is - as the name might already disclose - a vim plugin to support markdown based creating/editing of confluence cloud pages

### Usage

``` 
vim conf://<SPACEKEY>/<PAGETITLE>
```

To edit confluence pages within vim use the **conf://** prefix followed by the spacekey and the pagetitle

### Dependencies

The plugin makes use of the following python modules 
* json
* html2text
* markdown
* requests
* vim

### Configuration

The plugin expects two vim configuration settings to be added to your vimrc

confluence_url defines the url of the rest api endpoint of your confluence cloud instance

```
let g:confluence_url= 'https://YOURINSTANCE.atlassian.net/wiki/rest/api/'
```
confluence_auth contains a base 64 encoded string that consits out of your username and the api access token
```
let g:confluence_auth= 'Basic <YOURGENERATEDBASE64STRING>'
```
To generate the auth string you can use the following command
```
echo -n <USERNAME>:<ACCESSTOKEN> | base64
```
to get an api access token please access https://id.atlassian.com/manage-profile/security/api-tokens

### Installation

Place the confluence-vim.vim file in your .vim/plugin folder

### Supported markdown tags

### Headings
```
# H1 Heading

## H2 Heading

### H3 Heading

#### H4 Heading

```

### Text formats

```
_Italics_

**Bold Text**
```

### Code
```
`print ("markdown")`
```

### Lists
```
Numbered list

 1. Item one
 2. Item two
 3. Item three

Unordered list

* Item a
* Item b
* Item c
```

### Links

```
[mobux.de - Klinners pages](https://mobux.de)
```

### Images

```
![Atlassian logo](https://wac-cdn.atlassian.com/dam/jcr:616e6748-ad8c-48d9-ae93-e49019ed5259/Atlassian-horizontal-blue-rgb.svg?cdnVersion=1369)
```

### Blockquotes

```
> Blockquotes are very handy in email to emulate reply text. This line is part of the same quote.

Quote break.

> This is a very long line that will still be quoted properly when it wraps. Oh boy let's keep writing to make sure this is long enough to actually wrap for everyone. Oh, you can _put_ **Markdown** into a blockquote.
```

### Horizontal rule
```
Horizontal rule Three or more...
 ***
Asterisks
```
### Inline HTML
```
<table>
    <tr>
       <td>Col A</td>
       <td>Col B</td>
    </tr>
</table>
```

### Confluence cloud specific tags
```
info[Content of the info panel]
note[Content of the note panel]
warning[Content of the warning panel]
```
