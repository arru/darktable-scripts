# -*- coding: utf-8 -*-
import sys
from flickrapi import FlickrAPI

FLICKR_PUBLIC = '<flickr api key goes here>'
FLICKR_SECRET = '<flickr secret api key goes here>'

FLICKR = FlickrAPI(FLICKR_PUBLIC, FLICKR_SECRET, format='parsed-json')

FLICKR.authenticate_via_browser(perms='write')

FLICKR.upload(filename=sys.argv[1], title=sys.argv[2],
              description=sys.argv[3],
              tags=sys.argv[4], format='etree')

