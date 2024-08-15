#ifndef ControllerAdapter_h
#define ControllerAdapter_h

#include "DeviceTasks.h"
#include <queue>
#include <memory>
#include <functional>

class ControllerAdapter
{
public:
    static void initializeQueue();
    virtual void notify(String type, std::string message) = 0;
    virtual String getName() = 0;
    static QueueHandle_t xTaskQueue;

    template <typename T>
    bool sendTask(T&& task) {
        QueueItem* item = new QueueItem(std::move(task));

        if (xQueueSend(xTaskQueue, &item, portMAX_DELAY) != pdPASS) {
            delete item;
            // Handle queue full situation
            return false;
        }
        return true;
    }
};

#endif