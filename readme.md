# NovelDownloader
  This project is motivated by that I am in the military service
  and want to read novel offline easily on mobile.
  Also I have bought a mooInk Pro last year,
  so even after the military service,
  I can benefit from the project.

  I will try to make this program more extensible so that it is not restricted to
  novel but any type of website,
  especialy I want to read some programming book which do not provide epub format.
  I think this may just be a self used project XD.

## Usage

   ```novelDownloader.pl [options] <url>```

   Example:

   ```novelDownloader.pl -o output.epub -f epub 'https://www.wenku8.net/modules/article/reader.php?aid=112'```

   This will download the novel whose index is at 'https://www.wenku8.net/modules/article/reader.php?aid=112', and output the novel to file **output.epub** with **epub** format

## Currently Supported Website
   - www.wenku8.com

     The index url should be **php** type rather than html type.

## How to Extend the Program
   - write downloader and exporter module which implement
     the **NovelDownloader::Downloader** and **NovelDownloader::Exporter** role, respectively.

     The roles are defined by Moose::Role,
     read the manual of Moose for more detail.

   - add the configuration of downloader and exporter to **processors.txt** file
   - then you should be able to download the content from the new website.

## Future of the Project
   Read **todo.org** for the todo list I have planned now.

## Author
   - Flotisable <s09930698@gmail.com>
