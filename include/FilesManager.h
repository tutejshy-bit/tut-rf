#ifndef FilesManager_h
#define FilesManager_h

#include <sstream>

#include "SD.h"

class FilesManager
{
  public:
    FilesManager() {}

    File open(std::string path, const char* mode)
    {
        return SD.open(path.c_str(), mode);
    }

    std::string listFiles(const std::string& path)
    {
        File dir = SD.open(path.c_str());
        std::ostringstream fileList;
        fileList << "[";
        bool firstFile = true;
        while (File entry = dir.openNextFile()) {
            if (!firstFile) {
                fileList << ",";
            }

            std::string fullPath(entry.name());
            std::string filename = fullPath.substr(fullPath.find_last_of('/') + 1);
            if (!entry.isDirectory()) {
                fileList << "{\"name\": \"" << filename << "\", \"size\": " << entry.size() << ", \"date\": \"" << entry.getLastWrite() << "\", \"type\": \"file\"}";
            } else {
                fileList << "{\"name\": \"" << filename << "\", \"type\": \"directory\"}";
            }
            firstFile = false;
            entry.close();
        }
        fileList << "]";
        dir.close();
        return fileList.str();
    }
    std::string listAllFiles(const std::string& path)
    {
        File dir = SD.open(path.c_str());
        std::string filesList = listFilesRecursive(dir);
        dir.close();
        return filesList;
    }

    std::string listFilesRecursive(File dir)
    {
        std::ostringstream fileList;
        fileList << "[";
        bool firstFile = true;
        while (File entry = dir.openNextFile()) {
            if (!firstFile) {
                fileList << ",";
            }

            std::string fullPath(entry.name());
            std::string filename = fullPath.substr(fullPath.find_last_of('/') + 1);
            if (!entry.isDirectory()) {
                fileList << "{\"name\": \"" << filename << "\", \"size\": " << entry.size() << ", \"date\": \"" << entry.getLastWrite() << "\", \"type\": \"file\"}";
            } else {
                fileList << "{\"name\": \"" << filename << "\", \"type\": \"directory\", \"contains\": " << listFilesRecursive(entry) << "}";
            }
            firstFile = false;
            entry.close();
        }
        fileList << "]";
        return fileList.str();
    }

    std::string getFile(const std::string& filename)
    {

        File file = SD.open(String("/DATA/RECORDS/") + filename.c_str(), FILE_READ);
        if (!file) {
            return "File not found";
        }

        std::ostringstream fileContent;
        while (file.available()) {
            fileContent << static_cast<char>(file.read());
        }
        file.close();
        return fileContent.str();
    }

    bool createDirectory(const std::string& dirPath)
    {
        String path = String(dirPath.c_str());
        if (!SD.exists(path)) {
            return SD.mkdir(path);
        }
        return false;
    }

    bool remove(const std::string& path)
    {
        if (!SD.exists(path.c_str())) {
            return false;
        }
        File file = SD.open(path.c_str());
        if (file.isDirectory()) {
            file.close();
            return SD.rmdir(path.c_str());
        }
        file.close();
        return SD.remove(path.c_str());
    }

    bool rename(const std::string& from, const std::string& to)
    {
        if (!SD.exists(from.c_str()) || SD.exists(to.c_str())) {
            return false;
        }
        return SD.rename(from.c_str(), to.c_str());
    }
};

extern FilesManager filesManager;

#endif