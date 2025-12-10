#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "climatedatamodel.h"

// Global pointer to connect model and provider
static ClimateDataModel *g_climateModel = nullptr;
static ClimateTextureProvider *g_textureProvider = nullptr;

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQuickStyle::setStyle("Basic");

    QQmlApplicationEngine engine;

    // Create and register the texture provider
    g_textureProvider = new ClimateTextureProvider();
    engine.addImageProvider("climatedata", g_textureProvider);

    // Create the climate model and expose it to QML
    g_climateModel = new ClimateDataModel();
    g_textureProvider->setModel(g_climateModel);
    engine.rootContext()->setContextProperty("climateDataModel", g_climateModel);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("MapDataOverlay", "Main");

    return app.exec();
}
