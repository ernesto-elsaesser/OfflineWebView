# OfflineWebView

This project contains the following three targets:

**WebArchiver**

The reusable framework that does the actual work. The main method `WebArchiver.achive(...)` takes an URL and optionally a list of cookies. The archiver will download the main HTML document and all linked HTML, CSS, JavaScript* and image resources. All resources are then archived into a single .webarchive file (which is just a binary PLIST file). There doesn't seem to be an official documentation of the webarchive format, but it is possible to reconstruct the relevant key names from archive files created by Safari. The archiver does parallelize HTTP requests, but works on a single serial queue to process the responses.

**JavaScript can be excluded if not wanted/needed*

**OfflineWebView**

This is just a very basic (and quite ugly) sample app that showcases how the `WebArchiver` can be used in combination with a `WKWebView`. It also shows how cookies can be extracted from the WebKit session to be used for archiving. Change the `homepageURL` in the view controller to test with your web page.

**WebArchiverTests**

Just one single test, to make sure the archiver still works.

### Limitations

The web archiver will only work well with static content. As soon as a web needs to dynamically load resources via JavaScript, there is no sane way to archive that page into a single file without virtually replicating the backend. The archiver also doesn't scan JavaScript for statically linked resources. It does scan CSS files for image URLs though.

The archiver is further limited to the common resource types of web pages, i.e. HTML, CSS, JavaScript and images. If a web page has statically linked resources of other types (i.e. audio, video, ...) these resources won't be included in the archive. If you need to support such pages, I recommend to fork the repo and extend the archiver to include the required types.

### Dependencies

The project uses CocoaPods for dependency management. The only dependency is the HTML parser [Fuzi](https://github.com/cezheng/Fuzi).