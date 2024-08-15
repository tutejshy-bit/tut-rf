#include "ClientsManager.h"

ClientsManager& ClientsManager::getInstance() {
    static ClientsManager instance;
    return instance;
}

ClientsManager::ClientsManager() : clientsNotificationQueue(nullptr) {}


ClientsManager::~ClientsManager() {
    if (clientsNotificationQueue != nullptr) {
        vQueueDelete(clientsNotificationQueue);
    }
}

void ClientsManager::initializeQueue(size_t queueSize) {
    if (clientsNotificationQueue == nullptr) {
        clientsNotificationQueue = xQueueCreate(queueSize, sizeof(Notification));
    }
}

void ClientsManager::addAdapter(ControllerAdapter* adapter)
{
    adapters[adapter->getName().c_str()] = adapter;
}

void ClientsManager::removeAdapter(const std::string& name)
{
    adapters.erase(name);
}

void ClientsManager::notifyAll(NotificationType type, std::string message)
{
    String typeName = NotificationTypeToString(type);
    for (const auto& pair : adapters) {
        pair.second->notify(typeName, message);
    }
}

void ClientsManager::notifyByName(const std::string& name, NotificationType type, std::string message)
{
    String typeName = NotificationTypeToString(type);
    if (adapters.find(name) != adapters.end()) {
        adapters[name]->notify(typeName, message);
    }
}

bool ClientsManager::enqueueMessage(NotificationType type, const std::string& message)
{
    if (clientsNotificationQueue == nullptr) {
        return false;
    }

    Notification notification = {type, message};
    if (xQueueSend(clientsNotificationQueue, &notification, portMAX_DELAY) != pdPASS) {
        return false;
    }

    return true;
}

void ClientsManager::processMessageQueue(void *taskParameters) {
    Notification notification;

    while (true) {
        if (xQueueReceive(ClientsManager::getInstance().clientsNotificationQueue, &notification, portMAX_DELAY)) {
            ClientsManager::getInstance().notifyAll(notification.type, notification.message);
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}