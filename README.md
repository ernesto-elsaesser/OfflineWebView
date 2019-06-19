# OfflineWebView

This project contains following three targets:

**WebArchiver**

The reusable framework that does the actual work. The main method `WebArchiver.achive(...)` takes an URL and optionally a list of cookies. The archiver will download the main HTML document and all linked HTML, CSS, JavaScript* and image resources. All resources get stored in a single .webarchive file, which is just a binary PLIST following a specified format. There doesn't seem to be an official documentation of all possible keys, but it is possible to reconstruct the format from .webarchive files created by Safari. The archiver does parallelize resource requests, but works on a single serial queue.

*JavaScript can be excluded if not wanted/needed

**OfflineWebView**

This is just a very basic and quite ugly sample app that showcases how the `WebArchiver` can be used in combination with a `WKWebView`. It is also shown how cookies can be extracted from the WebKit session to be used for archiving. Change the `homepageURL` in the view controller to test out your web page.

**WebArchiverTests**

Just one single test, to make sure the archiver still works.

### Limitations

The web archiver will only work well with static content. As soon as a web app has to dynamically load resources via JavaScript, there is no sane way to archive that page into a single file without virtually replicating the backend. The archiver also doesn't scan JavaScript for statically linked resources. It does scan CSS files for image URLs though.

The archiver is further limited to the 'default' resource types of web pages, i.e. more HTML, CSS, JavaScript and images. If a web page has statically linked resources of other types (i.e. audio, video, ...) these resources won't be included in the archive. In this case I recommend to fork the repo and extend the archiver so that it works well for your specific set of resource types.

### Dependencies

The project uses CocoaPods for dependency management. The only dependency is the HTML parser [Fuzi](https://github.com/cezheng/Fuzi).