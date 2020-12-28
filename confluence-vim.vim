if !has('python3')
    echo "Error: Required vim compiled with +python3"
    finish
endif
python3 << EOF
#Dictionaries containg the confluence specific macros and their equivalent vim markdown tags
#Details cna be found while looking at the storage format information
md2confluence = {r'```(.*?)```':r'<ac:structured-macro ac:name="code"><ac:plain-text-body><![CDATA[\1]]></ac:plain-text-body></ac:structured-macro>',
    r'info\[(.*?)\]':r'<ac:structured-macro ac:name="info"><ac:rich-text-body> <p>\1</p></ac:rich-text-body></ac:structured-macro>',
    r'warning\[(.*?)\]':r'<ac:structured-macro ac:name="warning"><ac:rich-text-body> <p>\1</p></ac:rich-text-body></ac:structured-macro>',
    r'note\[(.*?)\]':r'<ac:structured-macro ac:name="note"><ac:rich-text-body> <p>\1</p></ac:rich-text-body></ac:structured-macro>'}

confluence2md = {r'<ac:structured-macro ac:name="info" ac:schema-version="1" ac:macro-id=".*?"><ac:rich-text-body>\s*<p>(.*?)</p></ac:rich-text-body></ac:structured-macro>':r'info[\1]',
           r'<ac:structured-macro ac:name="code" ac:schema-version="1" .*?><ac:plain-text-body><!\[CDATA\[(.*?)\]\]></ac:plain-text-body></ac:structured-macro>':r'```\1```',
           r'<ac:structured-macro ac:name="warning" ac:schema-version="1" ac:macro-id=".*?"><ac:rich-text-body>\s*<p>(.*?)</p></ac:rich-text-body></ac:structured-macro>':r'warning[\1]',
           r'<ac:structured-macro ac:name="note" ac:schema-version="1" ac:macro-id=".*?"><ac:rich-text-body>\s*<p>(.*?)</p></ac:rich-text-body></ac:structured-macro>':r'note[\1]'}

class RegexDict(dict):
    """
    RegexDict takes an dictionary and replaces within 
    a provided string the values contained in the 
    keys of the dict through the corresponding values
    """
    import re
    def __init__(self, *args, **kwds):
        self.update(*args, **kwds)

    def __getitem__(self, required):
        for key in dict.__iter__(self):
            if self.re.search(key, required,flags=self.re.MULTILINE | self.re.DOTALL):
                required=self.re.sub(key,dict.__getitem__(self, key),required,0,self.re.DOTALL | self.re.MULTILINE)
            else:
                required=required
        return required

EOF

function! OpenConfluencePage(url)
python3 << EOF
"""
Get data for existing confluence articles
"""
import json
import html2text
import requests
import vim
import re

class Error(Exception):
    """ Base error class for module specific exceptions """
    #pass

class SpaceKeyError(Error):
    """
    Exception raised for errors in the input.
     Attributes:
       message -- explanation of the error
    """
    def __init__(self, message):
        self.message = message

class ParentPageError(Error):
    """
    Exception raised for errors in the input.
     Attributes:
       message -- explanation of the error
    """
    def __init__(self, message):
        self.message = message

cb = vim.current.buffer

# confluence_url and confluence_auth should be defined in the .vimrc file
# while confluence_url should point to the content rest api endpoint of your
# instance 'https://<YOURDOMAIN>.atlassian.net/wiki/rest/api/content/'
# confluence_auth contains the base64 encoded username:password information
confluence_instance = vim.eval("g:confluence_url")
confluence_auth = vim.eval("g:confluence_auth")

url = vim.eval("a:url")

request_headers = {
    "Accept": "application/json",
    "Authorization": confluence_auth
}

try:
    from urllib.parse import urlparse
    article_space = urlparse(url).netloc
    article_path = urlparse(url).path
    article_title = article_path.split("/")[-1]
    article_parent_page = article_path.split("/")[-2]
    article_parent_pageid=-1

    vim.command("let b:article_title =  '%s'" % article_title)
    vim.command("let b:parent_page =  '%s'" % article_parent_page)
    vim.command("let b:space_name = '%s'" % article_space)
    # Check if a valid spacekey had been provided
    # Only if that is the case the option to save the article
    # will be available
    try:
        request_url = confluence_instance + 'space/' +  article_space
        response = requests.get(
            request_url,
            headers=request_headers
        )
        if response.status_code != 200:
            raise SpaceKeyError("Space name " + article_space + " seems to be invalid")

        try:
            # search the parent page via cql
            request_url = confluence_instance + 'content/search'
            query = {
                'cql': '{title="' + article_parent_page + '" and space="' + article_space + '"}'
            }
            response = requests.get(
                request_url,
                headers=request_headers,
                params=query
            )

            if response.status_code == 200:
                response = json.loads(response.text)
                article_parent_pageid = response['results'][0]['id']

            vim.command("let b:parent_pageid =  '%s'" % article_parent_pageid)
            try:
                # search the specified page via cql
                request_url = confluence_instance + 'content/search'
                if article_parent_pageid != -1:
                    query = {
                        'cql': '{title="' + article_title + '" and space="' + article_space + '" and parent="' + article_parent_pageid + '"}'
                    }
                else:
                    query = {
                        'cql': '{title="' + article_title + '" and space="' + article_space + '"}'
                    }
                response = requests.get(
                    request_url,
                    headers=request_headers,
                    params=query
                )

                if response.status_code == 200:
                    response = json.loads(response.text)

                    article_id = response['results'][0]['id']
                    vim.command("let b:confid = '%s'" % article_id)

                    # Get the article_content
                    request_url = confluence_instance + 'content/' + article_id + \
                        "?expand=body.storage,version.number"
                    response = requests.request(
                        "GET",
                        request_url,
                        headers=request_headers,
                        params=query)

                    if response.status_code == 200:
                        article_data = json.loads(response.text)
                        article_content = article_data['body']['storage']['value']
                        article_version = article_data['version']['number']
                        h2t = html2text.HTML2Text()
                        h2t.body_width = 0
                        regex_dict = RegexDict(confluence2md)
                        article_content=regex_dict[article_content]

                        #The markdown module addes some unnecessay paragraph tags within the code block
                        #as a workaround the code is stored before the markdown is generated and replaces 
                        #it after the generation with the original value
                        codemacro=re.search(r'```(.*)```', article_content, re.DOTALL | re.MULTILINE)
                        if codemacro:
                            code="".join(codemacro.group(1))
                            article_content=re.sub('```(.*)```', 'CODEMACRO', article_content, 0,re.DOTALL | re.MULTILINE)
                        article_markdown = h2t.handle(article_content)
                        if codemacro:
                            article_markdown = re.sub('CODEMACRO','```' + code + '```' ,article_markdown,0,re.DOTALL|re.MULTILINE)

                        vim.command("let b:confv = '%s'" % article_version)

                        del cb[:]
                        for article_line in article_markdown.split('\n'):
                            cb.append(article_line.encode('utf8'))
                        del cb[0]
                    else:
                        vim.command("let b:confid = 0")
                        vim.command("let b:confv = 0")
                        vim.command("echo \"New confluence entry - %s\"" % article_title)
                        vim.command("set filetype=mkd")
            except IndexError:
                # not really an error, instead means there is no existing
                # article and a new one will be created
                vim.command("let b:confid = 0")
                vim.command("let b:confv = 0")

        except IndexError:
            # not really an error, instead means there is no existing
            # article and a new one will be created
            vim.command('"echo \"Parent page %s seems to be invalid.\"" % article_parent_page')
            vim.command('let g:airline_section_a = "Error"' )
            vim.command('let g:airline_section_b = "Parent page %s seems to be invalid"' \
                % article_parent_page)
            vim.command("let b:confid = -1")
            vim.command("let b:confv = -1")

    except SpaceKeyError:
        vim.command('"echo \"Space name %s seems to be invalid.\"" % article_space')
        vim.command('let g:airline_section_a = "Error"' )
        vim.command('let g:airline_section_b = "Space name %s seems to be invalid"' \
            % article_space)
        vim.command("let b:confid = -1")
        vim.command("let b:confv = -1")
except AttributeError:
    vim.command('"echo \"Error while parsing url:.\"" % url')
    vim.command('let g:airline_section_a = "Error"' )
    vim.command('let g:airline_section_b = "Error while parsing url"' % url )
    vim.command("let b:confid = -1")
    vim.command("let b:confv = -1")
EOF
endfunction

function! WriteConfluencePage(url)
python3 << EOF
"""
Convert the current vim buffer into markdown
und store the page in the specific confluence space
"""
from markdown.preprocessors import Preprocessor
from markdown.postprocessors import Postprocessor
from markdown.extensions import Extension
import markdown
import re


class MacroRender(Preprocessor):
    def run(self, lines):
        regex_dict = RegexDict(md2confluence)
        content="\n".join(lines)
        output=regex_dict[content].splitlines()
        return output

class ConfluenceExtension(Extension):
    def extendMarkdown(self, md):
        md.preprocessors.register(MacroRender(md.parser), 'macro', 175)
        md.postprocessors.register(CodePostprocessor(md),'code',165)

class CodePostprocessor(Postprocessor):
    def run(self, html):
        #the braces around CDATA entities are replaced by the
        #corresponding html value < - &lt,
        #the regex below are used to revert that change
        html=re.sub(r'&lt;!\[CDATA',r'<![CDATA',html)
        html=re.sub(r'\]&gt;',r']>',html)
        return html

import json
import markdown
import requests
import vim

confluence_instance = vim.eval("g:confluence_url")
confluence_auth = vim.eval("g:confluence_auth")

url = vim.eval("a:url")

headers = {
   "Accept": "application/json",
   "Content-Type": "application/json",
   "Authorization": confluence_auth
}

cb = vim.current.buffer

if int(vim.eval("b:confid")) >=0:
    article_title = str(vim.eval("b:article_title"))
    article_space = str(vim.eval("b:space_name"))
    article_parent_page = str(vim.eval("b:parent_page"))
    article_parent_pageid = int(vim.eval("b:parent_pageid"))
    article_id = int(vim.eval("b:confid"))
    article_version = int(vim.eval("b:confv")) + 1
    tmp="\n".join(cb)
    article_content = markdown.markdown(tmp, extensions=[ConfluenceExtension(),'md_in_html'])

    # Add a new post
    if article_id == 0:
        request_url = confluence_instance + 'content/'
        if article_parent_pageid > -1:
            payload = json.dumps({
                "title": article_title,
                "type": "page",
                "space": {
                    "key": article_space
                },
                "status": "current",
                "ancestors": [ {
                    "id": str(article_parent_pageid)
                } ], 
                "body": {
                    "storage": {
                        "value": article_content,
                        "representation": "storage"
                    }
                }
            })
        else:
            payload = json.dumps({
                "title": article_title,
                "type": "page",
                "space": {
                    "key": article_space
                },
                "status": "current",
                "body": {
                    "storage": {
                        "value": article_content,
                        "representation": "storage"
                    }
                }
            })
        response = requests.post(
            request_url,
            data=payload,
            headers=headers
        )
    # Update existing post
    else:
        request_url = confluence_instance + 'content/' +  str(article_id)
        if article_parent_pageid > -1: 
            payload = json.dumps({
                "version": {
                    "number": article_version
                },
                "title": article_title,
                "type": "page",
                "space": {
                    "key": article_space
                },
                "status": "current",
                "ancestors": [ {
                    "id": str(article_parent_pageid)
                } ], 
                "body": {
                    "storage": {
                         "value": article_content,
                         "representation": "storage"
                    }
                }
            })
        else:
            payload = json.dumps({
                "version": {
                    "number": article_version
                },
                "title": article_title,
                "type": "page",
                "space": {
                    "key": article_space
                },
                "status": "current",
                "body": {
                    "storage": {
                         "value": article_content,
                         "representation": "storage"
                    }
                }
            })
        response = requests.put(
            request_url,
            data=payload,
            headers=headers
        )
    response = json.loads(response.text)
    vim.command("let b:confv = %d" % int(response['version']['number']))
    vim.command("let b:confid = %d" % int(response['id']))
    vim.command("let &modified = 0")
    vim.command("echo \"Confluence entry %s written.\"" % article_title)
else:
    vim.command('"echo \"Space name %s seems to be invalid.\"" % article_space')
    vim.command('let g:airline_section_a = "Error"' )
    vim.command('let g:airline_section_b = "Space name %s seems to be invalid"'  % article_space)
EOF
endfunction

augroup Confluence
  au!
  au BufReadCmd conf://*  call OpenConfluencePage(expand("<amatch>"))
  au BufWriteCmd conf://*  call WriteConfluencePage(expand("<amatch>"))
augroup END
