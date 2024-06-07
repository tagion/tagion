import os
from xml.etree import ElementTree as ET
import sys

def add_url(root, location):
    url_element = ET.Element("url")
    loc_element = ET.SubElement(url_element, "loc")
    loc_element.text = location
    changefreq_element = ET.SubElement(url_element, "changefreq")
    changefreq_element.text = "weekly"
    priority_element = ET.SubElement(url_element, "priority")
    priority_element.text = "0.5"
    root.append(url_element)

def main():
    # Get paths from command line arguments
    if len(sys.argv) != 3:
        print("Usage: python script.py /path/to/sitemap.xml /path/to/ddoc/folder")
        sys.exit(1)

    sitemap_path = sys.argv[1]
    ddoc_folder = sys.argv[2]

    # Parse the existing sitemap.xml
    tree = ET.parse(sitemap_path)
    root = tree.getroot()

    # Loop through files in the ddoc folder and add them to the sitemap
    for filename in os.listdir(ddoc_folder):
        if filename.endswith(".html"):
            # Construct the URL by appending the filename to the base URL
            url = f"https://docs.tagion.org/ddoc/{filename}"

            # Add the URL to the sitemap
            add_url(root, url)

    # Save the modified sitemap
    tree.write(sitemap_path, encoding="utf-8", xml_declaration=True)

if __name__ == "__main__":
    main()
