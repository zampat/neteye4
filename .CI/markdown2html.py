import mistune
import sys


with open(sys.argv[1], "r") as input_markdown:
    content = input_markdown.read()
    parsed_html = mistune.markdown(content)
    with open("{}.html".format(sys.argv[1]), "w") as output_html:
        output_html.write(parsed_html)
