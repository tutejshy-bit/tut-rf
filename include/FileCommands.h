#ifndef FileCommands_h
#define FileCommands_h

#include "StringBuffer.h"
#include "CommandHandler.h"
#include "ClientsManager.h"
#include "StringHelpers.h"
#include "BinaryMessages.h"
#include "BleAdapter.h"
#include "SD.h"
#include "Arduino.h"
#include <cstring>  // For strrchr

// Forward declarations
extern ClientsManager& clients;

/**
 * Файловые команды с использованием статических буферов
 * вместо динамических строк для экономии памяти на микроконтроллере
 */
class FileCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x05, handleGetFilesList);
        handler.registerCommand(0x09, handleLoadFileData);
        handler.registerCommand(0x0B, handleRemoveFile);
        handler.registerCommand(0x0C, handleRenameFile);
        handler.registerCommand(0x0A, handleCreateDirectory);
        // 0x0D (upload) is handled specially in BleAdapter::handleUploadChunk, not via CommandHandler
        handler.registerCommand(0x0E, handleCopyFile);
        handler.registerCommand(0x10, handleSaveToSignalsWithName);
        handler.registerCommand(0x12, handleGetDirectoryTree);
    }
    
private:
    // Статические буферы для избежания динамических аллокаций
    static JsonBuffer jsonBuffer;
    static PathBuffer pathBuffer;
    static LogBuffer logBuffer;
    
    // Вспомогательные функции для работы с путями
    /**
     * Строит базовый путь из pathType
     * @param pathType 0=RECORDS, 1=SIGNALS, 2=PRESETS, 3=TEMP
     * @param buffer буфер для результата
     */
    static void buildBasePath(uint8_t pathType, PathBuffer& buffer) {
        buffer.clear();
        buffer.append("/DATA/");
        switch (pathType) {
            case 0: buffer.append("RECORDS"); break;
            case 1: buffer.append("SIGNALS"); break;
            case 2: buffer.append("PRESETS"); break;
            case 3: buffer.append("TEMP"); break;
            default: buffer.append("RECORDS"); break;
        }
    }
    
    /**
     * Строит полный путь из pathType и относительного пути
     * @param pathType 0=RECORDS, 1=SIGNALS, 2=PRESETS, 3=TEMP
     * @param relativePath относительный путь (может быть пустым или "/")
     * @param pathLen длина относительного пути
     * @param buffer буфер для результата
     */
    static void buildFullPath(uint8_t pathType, const char* relativePath, size_t pathLen, PathBuffer& buffer) {
        buildBasePath(pathType, buffer);
        
        // Добавляем путь если не корневой
        if (pathLen > 0) {
            // Проверяем, не является ли путь корневым
            if (pathLen != 1 || relativePath[0] != '/') {
                buffer.append("/");
                
                // Убираем ведущий слеш если есть
                if (relativePath[0] == '/') {
                    buffer.append(relativePath + 1, pathLen - 1);
                } else {
                    buffer.append(relativePath, pathLen);
                }
            } else {
                // Корневой путь "/" - добавляем завершающий слеш для директории
                buffer.append("/");
            }
        } else {
            // Пустой путь - добавляем завершающий слеш для корневой директории
            buffer.append("/");
        }
    }
    
    /**
     * Извлекает имя файла из полного пути
     * @param fullPath полный путь
     * @param filename буфер для имени файла
     */
    static void extractFilename(const char* fullPath, PathBuffer& filename) {
        filename.clear();
        const char* lastSlash = strrchr(fullPath, '/');
        if (lastSlash) {
            filename.append(lastSlash + 1);
        } else {
            filename.append(fullPath);
        }
    }
    
    // Рекурсивное построение дерева директорий
    static bool buildDirectoryTreeRecursive(const char* basePath, JsonBuffer& buffer) {
        bool firstDir = true;
        bool hasDirectories = false;
        
        // Open directory
        File dir = SD.open(basePath);
        if (!dir || !dir.isDirectory()) {
            if (dir) dir.close();
            return false;
        }
        
        File entry;
        while ((entry = dir.openNextFile())) {
            if (entry.isDirectory()) {
                hasDirectories = true;
                
                // Extract directory name
                PathBuffer dirNameBuffer;
                extractFilename(entry.name(), dirNameBuffer);
                
                // Escape directory name for JSON
                PathBuffer escapedNameBuffer;
                const char* dirName = dirNameBuffer.c_str();
                size_t dirNameLen = dirNameBuffer.size();
                for (size_t i = 0; i < dirNameLen; i++) {
                    if (dirName[i] == '"') {
                        escapedNameBuffer.append("\\\"");
                    } else if (dirName[i] == '\\') {
                        escapedNameBuffer.append("\\\\");
                    } else {
                        escapedNameBuffer.append(dirName[i]);
                    }
                }
                
                // Build full path for this directory
                static PathBuffer fullPathBuffer;
                fullPathBuffer.clear();
                fullPathBuffer.append(basePath);
                if (basePath[strlen(basePath) - 1] != '/') {
                    fullPathBuffer.append("/");
                }
                fullPathBuffer.append(dirNameBuffer.c_str());
                
                // Build relative path (without base path)
                static PathBuffer relativePathBuffer;
                relativePathBuffer.clear();
                relativePathBuffer.append("/");
                relativePathBuffer.append(dirNameBuffer.c_str());
                
                if (!firstDir) {
                    buffer.append(",");
                }
                firstDir = false;
                
                // Start directory entry
                buffer.printf("{\"name\":\"%s\",\"path\":\"%s\",\"directories\":[", 
                             escapedNameBuffer.c_str(), relativePathBuffer.c_str());
                
                // Recursively add subdirectories
                bool hasSubDirs = buildDirectoryTreeRecursive(fullPathBuffer.c_str(), buffer);
                
                // Close directory entry
                buffer.append("]}");
            }
            entry.close();
        }
        
        dir.close();
        return hasDirectories;
    }
    
public:
    // Получение списка файлов
    static bool handleGetFilesList(const uint8_t* data, size_t len) {
        // CRITICAL: Prevent concurrent execution - if already processing, ignore new request
        static bool isProcessing = false;
        if (isProcessing) {
            ESP_LOGW("FileCommands", "handleGetFilesList already in progress, ignoring duplicate request");
            return false;  // Return false to indicate request was ignored
        }
        
        isProcessing = true;
        ESP_LOGI("FileCommands", "handleGetFilesList called: len=%d", len);
        
        // Use scope guard pattern - ensure cleanup on any return
        bool success = false;
        
        // Helper function to reset processing flag
        // Since isProcessing is static, we can't capture it in lambda
        // Instead, we'll reset it directly at each return point
        if (len < 2) {
            ESP_LOGW("FileCommands", "Insufficient data for getFilesList");
            isProcessing = false;
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        
        if (len < 2 + pathLength) {
            return false;
        }
        
        // Используем вспомогательную функцию для построения пути
        const char* path = (pathLength > 0) ? reinterpret_cast<const char*>(data + 2) : nullptr;
        buildFullPath(pathType, path, pathLength, pathBuffer);
        
        ESP_LOGI("FileCommands", "Path: pathLength=%d, pathType=%d, path='%.*s', final='%s'", 
                 pathLength, pathType, pathLength, (path ? path : ""), pathBuffer.c_str());
        
        // Проверка памяти
        if (ESP.getFreeHeap() < 3000) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Insufficient memory\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            isProcessing = false;
            return true;
        }
        
        try {
            // STREAMING VERSION: Read files one by one and send in chunks
            // Open directory once and keep it open until all files are read
            ESP_LOGI("FileCommands", "Attempting to open directory: '%s'", pathBuffer.c_str());
            
            // Ensure directory exists - create if it doesn't
            // Remove trailing '/' for exists/mkdir checks (SD library may require this)
            static PathBuffer dirPathWithoutSlash;
            dirPathWithoutSlash.clear();
            const char* pathStr = pathBuffer.c_str();
            size_t pathStrLen = strlen(pathStr);
            if (pathStrLen > 0 && pathStr[pathStrLen - 1] == '/') {
                dirPathWithoutSlash.append(pathStr, pathStrLen - 1);  // Remove trailing '/'
            } else {
                dirPathWithoutSlash.append(pathStr, pathStrLen);
            }
            
            if (!SD.exists(dirPathWithoutSlash.c_str())) {
                ESP_LOGI("FileCommands", "Directory does not exist, creating: '%s'", dirPathWithoutSlash.c_str());
                
                // Create all parent directories in order
                // For "/DATA/RECORDS", we need to create "/DATA" first, then "/DATA/RECORDS"
                const char* dirPathStr = dirPathWithoutSlash.c_str();
                size_t dirPathLen = strlen(dirPathStr);
                
                // Build parent directories step by step
                static PathBuffer currentPath;
                
                // Skip leading '/' and process each segment
                for (size_t i = 1; i < dirPathLen; i++) {  // Start from 1 to skip leading '/'
                    if (dirPathStr[i] == '/') {
                        // Found a segment boundary
                        currentPath.clear();
                        currentPath.append(dirPathStr, i);  // Include the '/'
                        
                        // Check without trailing slash
                        if (!SD.exists(currentPath.c_str())) {
                            ESP_LOGI("FileCommands", "Creating parent directory: '%s'", currentPath.c_str());
                            if (!SD.mkdir(currentPath.c_str())) {
                                ESP_LOGW("FileCommands", "Failed to create parent directory: '%s' (may already exist)", currentPath.c_str());
                            } else {
                                ESP_LOGI("FileCommands", "Parent directory created: '%s'", currentPath.c_str());
                            }
                        }
                    }
                }
                
                // Create the target directory (without trailing '/')
                if (!SD.mkdir(dirPathWithoutSlash.c_str())) {
                    ESP_LOGE("FileCommands", "Failed to create directory: '%s'", dirPathWithoutSlash.c_str());
                    jsonBuffer.clear();
                    jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Failed to create directory: %s\",\"files\":[]}", pathBuffer.c_str());
                    clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
                    isProcessing = false;
                    return true;
                }
                ESP_LOGI("FileCommands", "Directory created successfully: '%s'", dirPathWithoutSlash.c_str());
            }
            
            // Try opening directory without trailing slash (SD library may require this)
            // Use dirPathWithoutSlash which we already prepared above
            ESP_LOGI("FileCommands", "Opening directory (without trailing slash): '%s'", dirPathWithoutSlash.c_str());
            File dir = SD.open(dirPathWithoutSlash.c_str());
            if (!dir) {
                ESP_LOGE("FileCommands", "Failed to open directory: '%s' (SD card may not be mounted or path incorrect)", dirPathWithoutSlash.c_str());
                // Try with trailing slash as fallback
                ESP_LOGI("FileCommands", "Trying with trailing slash: '%s'", pathBuffer.c_str());
                dir = SD.open(pathBuffer.c_str());
                if (!dir) {
                    ESP_LOGE("FileCommands", "Failed to open directory with trailing slash too");
                    // Check if SD card is mounted
                    if (!SD.begin()) {
                        ESP_LOGE("FileCommands", "SD card not mounted!");
                    }
                    jsonBuffer.clear();
                    jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Failed to open directory: %s\",\"files\":[]}", pathBuffer.c_str());
                    clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
                    isProcessing = false;
                    return true;
                }
            }
            
            if (!dir.isDirectory()) {
                ESP_LOGE("FileCommands", "Path is not a directory: '%s'", dirPathWithoutSlash.c_str());
                dir.close();
                jsonBuffer.clear();
                jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Path is not a directory\",\"files\":[]}");
                clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
                isProcessing = false;
                return true;
            }
            
            ESP_LOGI("FileCommands", "Directory opened successfully: '%s'", dirPathWithoutSlash.c_str());
            
            // Build binary header: [0xA1][pathLen:1][path]
            size_t pathLen = strlen(pathBuffer.c_str());
            const size_t MAX_HEADER_SIZE = 256;
            uint8_t header[MAX_HEADER_SIZE];
            
            if (1 + 1 + pathLen > MAX_HEADER_SIZE) {
                ESP_LOGE("FileCommands", "Path too long for file list: %zu", pathLen);
                dir.close();
                jsonBuffer.clear();
                jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Path too long\"}");
                clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
                isProcessing = false;
                return true;
            }
            
            size_t offset = 0;
            header[offset++] = MSG_FILE_LIST;  // Binary file list message type
            header[offset++] = (uint8_t)pathLen;
            memcpy(header + offset, pathBuffer.c_str(), pathLen);
            offset += pathLen;
            size_t headerSize = offset;
            
            // Start building JSON in streaming mode
            // Use a static buffer to accumulate JSON until it reaches a certain size, then send
            const size_t CHUNK_SEND_SIZE = 800;  // Increased back to 800 bytes for better performance
            static ChunkBuffer chunkBuffer;  // Static buffer for accumulating JSON chunks (NO HEAP!)
            chunkBuffer.clear();
            
            // Start JSON: {"action":"list","files":[
            chunkBuffer.clear();
            if (!chunkBuffer.append("{\"action\":\"list\",\"files\":[")) {
                ESP_LOGE("FileCommands", "Failed to initialize chunk buffer");
                dir.close();
                jsonBuffer.clear();
                jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Buffer initialization failed\",\"files\":[]}");
                clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
                isProcessing = false;
                return true;
            }
            
            bool firstFile = true;
            int fileCount = 0;
            const int MAX_FILES = 1000;  // Reasonable limit
            bool bufferOverflow = false;  // Track if we hit buffer overflow
            
            // Reserve space for file entry (estimate: max ~200 bytes for long filename + JSON structure)
            const size_t FILE_ENTRY_RESERVE = 250;
            
            // Helper function to send current chunk
            auto sendCurrentChunk = [&]() -> bool {
                if (chunkBuffer.empty()) {
                    return true;  // Nothing to send
                }
                
                static uint8_t sharedMessageBuffer[256 + 800];
                if (headerSize + chunkBuffer.size() > sizeof(sharedMessageBuffer)) {
                    ESP_LOGE("FileCommands", "Message too large for static buffer");
                    bufferOverflow = true;
                    return false;
                }
                
                memcpy(sharedMessageBuffer, header, headerSize);
                memcpy(sharedMessageBuffer + headerSize, chunkBuffer.c_str(), chunkBuffer.size());
                
                clients.notifyAllBinary(NotificationType::FileSystem, 
                                      sharedMessageBuffer, 
                                      headerSize + chunkBuffer.size());
                
                chunkBuffer.clear();
                firstFile = true;  // Reset for next chunk
                return true;
            };
            
            File entry;
            while ((entry = dir.openNextFile()) && fileCount < MAX_FILES) {
                // Check memory periodically
                if (ESP.getFreeHeap() < 3000) {
                    ESP_LOGW("FileCommands", "Low memory at file %d, stopping", fileCount);
                    entry.close();
                    bufferOverflow = true;
                    break;
                }
                
                // Extract filename BEFORE checking buffer size (we need it for size estimation)
                PathBuffer filenameBuffer;
                extractFilename(entry.name(), filenameBuffer);
                
                // Escape filename for JSON
                PathBuffer escapedNameBuffer;
                const char* filename = filenameBuffer.c_str();
                size_t filenameLen = filenameBuffer.size();
                for (size_t i = 0; i < filenameLen; i++) {
                    if (filename[i] == '"') {
                        escapedNameBuffer.append("\\\"");
                    } else if (filename[i] == '\\') {
                        escapedNameBuffer.append("\\\\");
                    } else {
                        escapedNameBuffer.append(filename[i]);
                    }
                }
                
                // Estimate JSON entry size: base structure + escaped filename + size/date (for files)
                // Format: {"name":"...","size":123,"date":456,"type":"file"} or {"name":"...","type":"directory"}
                size_t estimatedEntrySize = 50;  // Base JSON structure
                estimatedEntrySize += escapedNameBuffer.size();  // Escaped filename
                if (!entry.isDirectory()) {
                    estimatedEntrySize += 30;  // Size and date fields
                }
                
                // Check if we need to send current chunk BEFORE adding new file
                // Send if buffer is close to full or if adding this file would overflow
                size_t currentSize = chunkBuffer.size();
                size_t freeSpace = chunkBuffer.capacity() - currentSize;
                
                // Need space for: comma (if not first) + estimated entry size
                size_t neededSpace = (firstFile ? 0 : 1) + estimatedEntrySize;
                
                if (freeSpace < neededSpace || currentSize >= CHUNK_SEND_SIZE) {
                    // Not enough space or already at send threshold - send current chunk first
                    if (!sendCurrentChunk()) {
                        entry.close();
                        break;  // Failed to send, stop processing
                    }
                }
                
                // Now we have space - add comma if not first file
                if (!firstFile) {
                    if (!chunkBuffer.append(",")) {
                        // This should not happen after our check, but handle it anyway
                        ESP_LOGE("FileCommands", "Unexpected: failed to append comma after buffer check");
                        entry.close();
                        break;
                    }
                }
                
                // Build file JSON entry - this should succeed now
                bool appendSuccess = false;
                if (!entry.isDirectory()) {
                    appendSuccess = chunkBuffer.printf("{\"name\":\"%s\",\"size\":%zu,\"date\":\"%lu\",\"type\":\"file\"}",
                                                      escapedNameBuffer.c_str(), entry.size(), entry.getLastWrite());
                } else {
                    appendSuccess = chunkBuffer.printf("{\"name\":\"%s\",\"type\":\"directory\"}", 
                                                      escapedNameBuffer.c_str());
                }
                
                if (!appendSuccess) {
                    // This should be rare now, but handle it
                    ESP_LOGE("FileCommands", "Unexpected: failed to append file after buffer check");
                    // Try to send current chunk and retry
                    if (!sendCurrentChunk()) {
                        entry.close();
                        break;
                    }
                    // Retry appending this file
                    if (!entry.isDirectory()) {
                        appendSuccess = chunkBuffer.printf("{\"name\":\"%s\",\"size\":%zu,\"date\":\"%lu\",\"type\":\"file\"}",
                                                         escapedNameBuffer.c_str(), entry.size(), entry.getLastWrite());
                    } else {
                        appendSuccess = chunkBuffer.printf("{\"name\":\"%s\",\"type\":\"directory\"}", 
                                                          escapedNameBuffer.c_str());
                    }
                    if (!appendSuccess) {
                        ESP_LOGE("FileCommands", "Failed to append file even after sending chunk - file entry too large");
                        entry.close();
                        bufferOverflow = true;
                        break;
                    }
                }
                
                firstFile = false;
                fileCount++;
                entry.close();
                
                // Check if we should send chunk after adding this file
                if (chunkBuffer.size() >= CHUNK_SEND_SIZE) {
                    if (!sendCurrentChunk()) {
                        break;  // Failed to send, stop processing
                    }
                }
            }
            
            // Close directory
            dir.close();
            
            // Handle empty directory case
            if (fileCount == 0) {
                // Send empty list immediately
                        jsonBuffer.clear();
                jsonBuffer.printf("{\"action\":\"list\",\"files\":[]}");
                
                // Use shared static buffer
                static uint8_t sharedMessageBuffer[256 + 800];  // Shared buffer for all message sending
                if (headerSize + jsonBuffer.size() > sizeof(sharedMessageBuffer)) {
                    ESP_LOGE("FileCommands", "Empty message too large");
                    return true;
                }
                
                memcpy(sharedMessageBuffer, header, headerSize);
                memcpy(sharedMessageBuffer + headerSize, jsonBuffer.c_str(), jsonBuffer.size());
                
                clients.notifyAllBinary(NotificationType::FileSystem, 
                                      sharedMessageBuffer, 
                                      headerSize + jsonBuffer.size());
                success = true;
                isProcessing = false;
                return true;
            }
            
            // Close JSON array and send final chunk
            // CRITICAL: Always ensure JSON is properly closed, even if we hit buffer overflow
            if (bufferOverflow && chunkBuffer.empty()) {
                // If buffer overflow and chunkBuffer is empty, we need to send closing brackets separately
                chunkBuffer.clear();
                chunkBuffer.append("]}");
            } else {
                // Try to append closing brackets, send separately if fails
                if (!chunkBuffer.append("]}")) {
                    ESP_LOGW("FileCommands", "Failed to append closing bracket, will send separately");
                    // Send current buffer first if not empty
                    if (!chunkBuffer.empty()) {
                        static uint8_t sharedMessageBuffer[256 + 800];
                        if (headerSize + chunkBuffer.size() <= sizeof(sharedMessageBuffer)) {
                            memcpy(sharedMessageBuffer, header, headerSize);
                            memcpy(sharedMessageBuffer + headerSize, chunkBuffer.c_str(), chunkBuffer.size());
                            clients.notifyAllBinary(NotificationType::FileSystem, 
                                                  sharedMessageBuffer, 
                                                  headerSize + chunkBuffer.size());
                        }
                    }
                    // Now send closing brackets
                    chunkBuffer.clear();
                    chunkBuffer.append("]}");
                }
            }
            
            // Build final message: header + final JSON chunk
            // Use shared static buffer to avoid heap allocation
            static uint8_t sharedMessageBuffer[256 + 800];  // Shared buffer for all message sending
            
            if (headerSize + chunkBuffer.size() > sizeof(sharedMessageBuffer)) {
                ESP_LOGE("FileCommands", "Final message too large for static buffer, trying minimal close");
                // Try to send just closing brackets in a separate message
                chunkBuffer.clear();
                chunkBuffer.append("]}");
                if (headerSize + chunkBuffer.size() <= sizeof(sharedMessageBuffer)) {
                    memcpy(sharedMessageBuffer, header, headerSize);
                    memcpy(sharedMessageBuffer + headerSize, chunkBuffer.c_str(), chunkBuffer.size());
                    clients.notifyAllBinary(NotificationType::FileSystem, 
                                          sharedMessageBuffer, 
                                          headerSize + chunkBuffer.size());
                    success = true;
                } else {
                    ESP_LOGE("FileCommands", "Cannot send closing brackets - buffer too small");
                    // Send error message as fallback
                    jsonBuffer.clear();
                    jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Buffer overflow: too many files\",\"files\":[]}");
                    clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
                }
                isProcessing = false;
                return true;
            }
            
            // Copy header
            memcpy(sharedMessageBuffer, header, headerSize);
            // Copy chunk data
            memcpy(sharedMessageBuffer + headerSize, chunkBuffer.c_str(), chunkBuffer.size());
            
            if (bufferOverflow) {
                ESP_LOGW("FileCommands", "Sending partial file list (buffer overflow): path='%s', files=%d, finalChunk=%zu bytes", 
                         pathBuffer.c_str(), fileCount, headerSize + chunkBuffer.size());
            } else {
                ESP_LOGI("FileCommands", "Sending file list (streaming): path='%s', files=%d, finalChunk=%zu bytes", 
                         pathBuffer.c_str(), fileCount, headerSize + chunkBuffer.size());
            }
            
            // Send final chunk
            clients.notifyAllBinary(NotificationType::FileSystem, 
                                  sharedMessageBuffer, 
                                  headerSize + chunkBuffer.size());
            
            if (bufferOverflow) {
                ESP_LOGW("FileCommands", "File list sent (partial): %d files (max reached), %zu bytes", fileCount, headerSize + chunkBuffer.size());
            } else {
                ESP_LOGI("FileCommands", "File list sent successfully: %d files, %zu bytes", fileCount, headerSize + chunkBuffer.size());
            }
            success = true;
            
        } catch (const std::bad_alloc& e) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Out of memory\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        } catch (...) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"list\",\"error\":\"Unknown error\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        }
        
        // CRITICAL: Reset processing flag before returning
        isProcessing = false;
        return success;
    }
    
    // Загрузка данных файла
    static bool handleLoadFileData(const uint8_t* data, size_t len) {
        if (len < 2) {
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        
        if (len < 2 + pathLength) {
            return false;
        }
        
        // Используем вспомогательную функцию для построения пути
        const char* path = (pathLength > 0) ? reinterpret_cast<const char*>(data + 2) : nullptr;
        buildFullPath(pathType, path, pathLength, pathBuffer);
        
        ESP_LOGI("FileCommands", "Final path: '%s'", pathBuffer.c_str());
        
        // Проверяем существование файла
        if (!SD.exists(pathBuffer.c_str())) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"load\",\"error\":\"File not found\",\"path\":\"%s\"}", 
                             pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return true;
        }
        
        // STREAM file directly from SD to BLE (NO buffering entire file!)
        // Uses minimal stack: static buffers only
        
        File file = SD.open(pathBuffer.c_str(), FILE_READ);
        if (!file) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"load\",\"error\":\"Failed to open file\",\"path\":\"%s\"}", 
                             pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return true;
        }
        
        size_t fileSize = file.size();
        ESP_LOGI("FileCommands", "Streaming file: %zu bytes (streaming, NO full buffering!)", fileSize);
        
        // Build header: [0xA0][pathLen:1][path][fileSize:4]
        size_t pathLen = strlen(pathBuffer.c_str());
        const size_t MAX_HEADER_SIZE = 256;
        uint8_t header[MAX_HEADER_SIZE];
        
        if (1 + 1 + pathLen + 4 > MAX_HEADER_SIZE) {
            ESP_LOGE("FileCommands", "Path too long: %zu", pathLen);
            file.close();
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"load\",\"error\":\"Path too long\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return true;
        }
        
        size_t offset = 0;
        header[offset++] = 0xA0;  // FILE_CONTENT message type
        header[offset++] = (uint8_t)pathLen;
        memcpy(header + offset, pathBuffer.c_str(), pathLen);
        offset += pathLen;
        
        // File size (4 bytes, little-endian)
        header[offset++] = (fileSize >> 0) & 0xFF;
        header[offset++] = (fileSize >> 8) & 0xFF;
        header[offset++] = (fileSize >> 16) & 0xFF;
        header[offset++] = (fileSize >> 24) & 0xFF;
        
        size_t headerSize = offset;
        
        // TRUE STREAMING: Use BLE adapter's streaming method
        // This reads file in small chunks and sends them immediately via BLE chunking
        // No need to load entire file into memory - true streaming!
        
        // Get BLE adapter instance
        BleAdapter* bleAdapter = BleAdapter::getInstance();
        if (bleAdapter != nullptr) {
            // Use streaming method - reads file parts and sends immediately
            bleAdapter->streamFileData(header, headerSize, file, fileSize);
            file.close();
            ESP_LOGI("FileCommands", "File streaming started: %zu bytes", fileSize);
        } else {
            // Fallback: use buffered approach if BLE adapter not available
            ESP_LOGW("FileCommands", "BLE adapter not available, using buffered approach");
            file.close();
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"load\",\"error\":\"BLE adapter not available\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        }
        
        return true;
    }
    
    static bool handleRemoveFile(const uint8_t* data, size_t len) {
        if (len < 2) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"delete\",\"success\":false,\"error\":\"Insufficient data\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        if (len < 2 + pathLength) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"delete\",\"success\":false,\"error\":\"Path length mismatch\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Build full path using helper function
        const char* path = reinterpret_cast<const char*>(data + 2);
        buildFullPath(pathType, path, pathLength, pathBuffer);
        
        // Check if path exists
        if (!SD.exists(pathBuffer.c_str())) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"delete\",\"success\":false,\"path\":\"%s\",\"error\":\"File or directory not found\"}", pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Check if it's a directory or file and remove accordingly
        File file = SD.open(pathBuffer.c_str());
        bool isDirectory = file.isDirectory();
        file.close();
        
        bool ok = false;
        if (isDirectory) {
            ok = SD.rmdir(pathBuffer.c_str());
        } else {
            ok = SD.remove(pathBuffer.c_str());
        }
        
        jsonBuffer.clear();
        if (ok) {
            jsonBuffer.printf("{\"action\":\"delete\",\"success\":true,\"path\":\"%s\"}", pathBuffer.c_str());
        } else {
            jsonBuffer.printf("{\"action\":\"delete\",\"success\":false,\"path\":\"%s\",\"error\":\"Delete failed\"}", pathBuffer.c_str());
        }
        clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        return ok;
    }
    
    static bool handleRenameFile(const uint8_t* data, size_t len) {
        if (len < 3) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"rename\",\"success\":false,\"error\":\"Insufficient data\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        uint8_t pathType = data[0];
        uint8_t fromLength = data[1];
        if (len < 2 + fromLength + 1) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"rename\",\"success\":false,\"error\":\"Invalid payload (to length missing)\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        const char* fromPtr = reinterpret_cast<const char*>(data + 2);
        uint8_t toLength = data[2 + fromLength];
        if (len < 3 + fromLength + toLength) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"rename\",\"success\":false,\"error\":\"Path length mismatch\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        const char* toPtr = reinterpret_cast<const char*>(data + 3 + fromLength);
        
        // Build full paths using helper functions
        // Use pathBuffer for "from" path
        buildFullPath(pathType, fromPtr, fromLength, pathBuffer);
        
        // Use a temporary PathBuffer for "to" path (we need both paths)
        static PathBuffer toPathBuffer;
        buildFullPath(pathType, toPtr, toLength, toPathBuffer);
        
        bool ok = SD.exists(pathBuffer.c_str()) && SD.rename(pathBuffer.c_str(), toPathBuffer.c_str());
        
        jsonBuffer.clear();
        if (ok) {
            jsonBuffer.printf("{\"action\":\"rename\",\"success\":true,\"from\":\"%s\",\"to\":\"%s\"}", pathBuffer.c_str(), toPathBuffer.c_str());
        } else {
            jsonBuffer.printf("{\"action\":\"rename\",\"success\":false,\"from\":\"%s\",\"to\":\"%s\",\"error\":\"Rename failed or source missing\"}", pathBuffer.c_str(), toPathBuffer.c_str());
        }
        clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        return ok;
    }
    
    static bool handleCreateDirectory(const uint8_t* data, size_t len) {
        if (len < 2) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"create-directory\",\"success\":false,\"error\":\"Insufficient data\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        if (len < 2 + pathLength) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"create-directory\",\"success\":false,\"error\":\"Path length mismatch\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Build paths using helper functions
        const char* dirPtr = reinterpret_cast<const char*>(data + 2);
        buildFullPath(pathType, dirPtr, pathLength, pathBuffer);
        
        // Get base directory for checking/creating
        static PathBuffer baseDirBuffer;
        buildBasePath(pathType, baseDirBuffer);
        
        bool ok = SD.exists(baseDirBuffer.c_str()) || SD.mkdir(baseDirBuffer.c_str());
        if (ok) {
            // Create the subdirectory
            if (!SD.exists(pathBuffer.c_str())) {
                ok = SD.mkdir(pathBuffer.c_str());
            }
        }
        
        jsonBuffer.clear();
        if (ok) {
            jsonBuffer.printf("{\"action\":\"create-directory\",\"success\":true,\"path\":\"%s\"}", pathBuffer.c_str());
        } else {
            jsonBuffer.printf("{\"action\":\"create-directory\",\"success\":false,\"path\":\"%s\",\"error\":\"Create directory failed\"}", pathBuffer.c_str());
        }
        clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        return ok;
    }
    
    static bool handleSaveToSignalsWithName(const uint8_t* data, size_t len) {
        if (len < 3) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"error\":\"Insufficient data\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Parse source path length, target name length, and path type
        uint8_t sourcePathLength = data[0];
        uint8_t targetNameLength = data[1];
        uint8_t pathType = data[2];
        
        if (len < 3 + sourcePathLength + targetNameLength) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"error\":\"Insufficient data for paths\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Extract source path
        if (sourcePathLength == 0 || sourcePathLength >= pathBuffer.capacity()) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"error\":\"Invalid source path length\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        const char* sourcePath = reinterpret_cast<const char*>(&data[3]);
        pathBuffer.clear();
        pathBuffer.append(sourcePath, sourcePathLength);
        
        // Extract target name to temporary buffer
        const char* targetName = reinterpret_cast<const char*>(&data[3 + sourcePathLength]);
        static PathBuffer targetNameBuffer;
        targetNameBuffer.clear();
        targetNameBuffer.append(targetName, targetNameLength);
        
        ESP_LOGI("FileCommands", "SaveToSignalsWithName: sourcePath=%s, targetName=%s, pathType=%d", 
                 pathBuffer.c_str(), targetNameBuffer.c_str(), pathType);
        
        // Build destination path using helper function
        static PathBuffer destPathBuffer;
        buildBasePath(pathType, destPathBuffer);
        destPathBuffer.append("/");
        destPathBuffer.append(targetNameBuffer.c_str());
        
        // Check if source file exists
        if (!SD.exists(pathBuffer.c_str())) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"error\":\"Source file not found\",\"path\":\"%s\"}", 
                             pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Create destination directory if it doesn't exist
        static PathBuffer baseDirBuffer;
        buildBasePath(pathType, baseDirBuffer);
        if (!SD.exists(baseDirBuffer.c_str())) {
            SD.mkdir(baseDirBuffer.c_str());
        }
        
        // Copy file from source to destination
        File sourceFile = SD.open(pathBuffer.c_str(), FILE_READ);
        if (!sourceFile) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"error\":\"Failed to open source file\",\"path\":\"%s\"}", 
                             pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        File destFile = SD.open(destPathBuffer.c_str(), FILE_WRITE);
        if (!destFile) {
            sourceFile.close();
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"error\":\"Failed to create destination file\",\"path\":\"%s\"}", 
                             destPathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Copy file content
        while (sourceFile.available()) {
            destFile.write(sourceFile.read());
        }
        
        sourceFile.close();
        destFile.close();
        
        ESP_LOGI("FileCommands", "File copied successfully: %s -> %s", pathBuffer.c_str(), destPathBuffer.c_str());
        
        // Send success response
        jsonBuffer.clear();
        jsonBuffer.printf("{\"type\":\"FileSavedWithName\",\"data\":{\"sourcePath\":\"%s\",\"targetName\":\"%s\",\"destPath\":\"%s\"}}",
                         pathBuffer.c_str(),
                         targetNameBuffer.c_str(),
                         destPathBuffer.c_str());
        clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        
        return true;
    }
    
    // Копирование файла
    static bool handleCopyFile(const uint8_t* data, size_t len) {
        if (len < 3) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"copy\",\"success\":false,\"error\":\"Insufficient data\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        uint8_t pathType = data[0];
        uint8_t sourceLength = data[1];
        if (len < 2 + sourceLength + 1) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"copy\",\"success\":false,\"error\":\"Invalid payload (dest length missing)\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        const char* sourcePtr = reinterpret_cast<const char*>(data + 2);
        uint8_t destLength = data[2 + sourceLength];
        if (len < 3 + sourceLength + destLength) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"copy\",\"success\":false,\"error\":\"Path length mismatch\"}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        const char* destPtr = reinterpret_cast<const char*>(data + 3 + sourceLength);
        
        // Build full paths using helper functions
        buildFullPath(pathType, sourcePtr, sourceLength, pathBuffer);
        
        // Use a temporary PathBuffer for destination path
        static PathBuffer destPathBuffer;
        buildFullPath(pathType, destPtr, destLength, destPathBuffer);
        
        // Check if source file exists
        if (!SD.exists(pathBuffer.c_str())) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"copy\",\"success\":false,\"error\":\"Source file not found\",\"source\":\"%s\"}", pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Copy file from source to destination
        File sourceFile = SD.open(pathBuffer.c_str(), FILE_READ);
        if (!sourceFile) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"copy\",\"success\":false,\"error\":\"Failed to open source file\",\"source\":\"%s\"}", pathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        File destFile = SD.open(destPathBuffer.c_str(), FILE_WRITE);
        if (!destFile) {
            sourceFile.close();
            jsonBuffer.clear();
            jsonBuffer.printf("{\"action\":\"copy\",\"success\":false,\"error\":\"Failed to create destination file\",\"dest\":\"%s\"}", destPathBuffer.c_str());
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        // Copy file content
        while (sourceFile.available()) {
            destFile.write(sourceFile.read());
        }
        
        sourceFile.close();
        destFile.close();
        
        ESP_LOGI("FileCommands", "File copied successfully: %s -> %s", pathBuffer.c_str(), destPathBuffer.c_str());
        
        // Send success response
        jsonBuffer.clear();
        jsonBuffer.printf("{\"action\":\"copy\",\"success\":true,\"source\":\"%s\",\"dest\":\"%s\"}", pathBuffer.c_str(), destPathBuffer.c_str());
        clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        
        return true;
    }
    
    // Получение дерева директорий (только директории, рекурсивно)
    static bool handleGetDirectoryTree(const uint8_t* data, size_t len) {
        if (len < 1) {
            jsonBuffer.clear();
            jsonBuffer.printf("{\"type\":\"DirectoryTree\",\"data\":{\"error\":\"Insufficient data\"}}");
            clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
            return false;
        }
        
        uint8_t pathType = data[0];
        
        // Build base path
        buildBasePath(pathType, pathBuffer);
        
        ESP_LOGI("FileCommands", "Getting directory tree for pathType=%d, basePath='%s'", pathType, pathBuffer.c_str());
        
        // Recursively build directory tree
        jsonBuffer.clear();
        jsonBuffer.append("{\"type\":\"DirectoryTree\",\"data\":{\"pathType\":");
        jsonBuffer.printf("%d", pathType);
        jsonBuffer.append(",\"directories\":[");
        
        bool hasDirectories = buildDirectoryTreeRecursive(pathBuffer.c_str(), jsonBuffer);
        
        jsonBuffer.append("]}}");
        
        // Send directory tree via JSON message
        clients.enqueueMessage(NotificationType::FileSystem, jsonBuffer.c_str());
        
        ESP_LOGI("FileCommands", "Directory tree sent: %d directories", hasDirectories ? 1 : 0);
        return true;
    }
    
    // Загрузка файла (upload) с чанкингом
    // Примечание: Команда 0x0D больше не регистрируется в CommandHandler
    // Реальная обработка происходит в BleAdapter::handleUploadChunk
    // Этот метод оставлен для совместимости, но не должен вызываться
    static bool handleUploadFile(const uint8_t* data, size_t len) {
        // Команда 0x0D обрабатывается в BleAdapter::handleUploadChunk
        // Этот метод не должен вызываться
        return false;
    }
};

// Статические буферы
JsonBuffer FileCommands::jsonBuffer;
PathBuffer FileCommands::pathBuffer;
LogBuffer FileCommands::logBuffer;

#endif // FileCommands_h
