#ifndef ClientsManager_h
#define ClientsManager_h

#include <map>
#include <string>
#include <queue>

#include "ControllerAdapter.h"

enum class NotificationType
{
    SignalDetected,
    SignalRecorded,
    SignalRecordError,
    SignalSent,
    SignalSendingError,
    State,
    ModeSwitch,
    FileSystem,
    FileUpload,
    Unknown
};

inline const String NotificationTypeToString(NotificationType v)
{
    switch (v) {
        case NotificationType::SignalDetected:
            return "SignalDetected";
        case NotificationType::SignalRecorded:
            return "SignalRecorded";
        case NotificationType::SignalRecordError:
            return "SignalRecordError";
        case NotificationType::SignalSent:
            return "SignalSent";
        case NotificationType::SignalSendingError:
            return "SignalSendingError";
        case NotificationType::ModeSwitch:
            return "ModeSwitch";
        case NotificationType::FileSystem:
            return "FileSystem";
        case NotificationType::FileUpload:
            return "FileUpload";
        case NotificationType::State:
            return "State";
        default:
            return "Unknown";
    }
}

struct Notification
{
    NotificationType type;
    std::string message;

    Notification() : type(NotificationType::Unknown), message("") {}
    Notification(NotificationType t, std::string m) : type(t), message(m) {}
};

class ClientsManager
{
  public:
    static ClientsManager& getInstance();

    void addAdapter(ControllerAdapter* adapter);
    void removeAdapter(const std::string& name);
    void notifyAll(NotificationType type, std::string message);
    void notifyByName(const std::string& name, NotificationType type, std::string message);
    void initializeQueue(size_t queueSize);

    bool enqueueMessage(NotificationType, const std::string& message);
    static void processMessageQueue(void *taskParameters);

  private:
    ClientsManager();
    ~ClientsManager();
    ClientsManager(const ClientsManager&) = delete;
    ClientsManager& operator=(const ClientsManager&) = delete;
    QueueHandle_t clientsNotificationQueue;
    std::map<std::string, ControllerAdapter*> adapters;
};

#endif  // Clients_h