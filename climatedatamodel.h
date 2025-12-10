#ifndef CLIMATEDATAMODEL_H
#define CLIMATEDATAMODEL_H

#include <QObject>
#include <QImage>
#include <QQuickImageProvider>
#include <QtQml/qqmlregistration.h>

class ClimateDataModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString databasePath READ databasePath WRITE setDatabasePath NOTIFY databasePathChanged)
    Q_PROPERTY(QString activeColumn READ activeColumn WRITE setActiveColumn NOTIFY activeColumnChanged)
    Q_PROPERTY(int pointCount READ pointCount NOTIFY dataChanged)
    Q_PROPERTY(QStringList availableColumns READ availableColumns CONSTANT)
    Q_PROPERTY(double minValue READ minValue NOTIFY dataChanged)
    Q_PROPERTY(double maxValue READ maxValue NOTIFY dataChanged)
    Q_PROPERTY(int textureWidth READ textureWidth NOTIFY dataChanged)
    Q_PROPERTY(int textureHeight READ textureHeight NOTIFY dataChanged)
    Q_PROPERTY(double gridResolution READ gridResolution NOTIFY dataChanged)
    Q_PROPERTY(double minLat READ minLat NOTIFY dataChanged)
    Q_PROPERTY(double maxLat READ maxLat NOTIFY dataChanged)
    Q_PROPERTY(double minLon READ minLon NOTIFY dataChanged)
    Q_PROPERTY(double maxLon READ maxLon NOTIFY dataChanged)

public:
    explicit ClimateDataModel(QObject *parent = nullptr);

    QString databasePath() const;
    void setDatabasePath(const QString &path);

    QString activeColumn() const;
    void setActiveColumn(const QString &column);

    int pointCount() const;
    QStringList availableColumns() const;

    double minValue() const;
    double maxValue() const;

    int textureWidth() const;
    int textureHeight() const;
    double gridResolution() const;
    double minLat() const { return m_minLat; }
    double maxLat() const { return m_maxLat; }
    double minLon() const { return m_minLon; }
    double maxLon() const { return m_maxLon; }

    // Get the data texture (normalized values encoded in red channel)
    QImage dataTexture() const;

    // Load data from the database
    Q_INVOKABLE bool loadData();

    // Get raw value at a specific coordinate (returns NaN if no data)
    Q_INVOKABLE double getValueAt(double lat, double lon) const;

    // Check if there's valid data at a coordinate
    Q_INVOKABLE bool hasDataAt(double lat, double lon) const;

signals:
    void databasePathChanged();
    void activeColumnChanged();
    void dataChanged();

private:
    void calculateMinMax();
    void detectGridResolution();
    void generateTexture();
    double normalizeValue(double value) const;

    // Convert lat/lon to texture coordinates
    int latToTextureY(double lat) const;
    int lonToTextureX(double lon) const;

    QString m_databasePath;
    QString m_activeColumn = "TAMB_Mean";

    // Store raw data
    struct DataPoint {
        double lat;
        double lon;
        double tambMean;
        double tambDelta;
    };
    QVector<DataPoint> m_dataPoints;

    // Grid parameters (detected from data)
    double m_gridResolution = 0.25;  // degrees
    double m_minLat = -90.0;
    double m_maxLat = 90.0;
    double m_minLon = -180.0;
    double m_maxLon = 180.0;

    // Texture dimensions
    int m_textureWidth = 1440;   // 360 / 0.25
    int m_textureHeight = 720;   // 180 / 0.25

    // Data range for normalization
    double m_minValue = 0.0;
    double m_maxValue = 1.0;

    // Generated texture
    QImage m_dataTexture;
};

// Image provider to expose the texture to QML
class ClimateTextureProvider : public QQuickImageProvider
{
public:
    ClimateTextureProvider();

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    void setModel(ClimateDataModel *model);

private:
    ClimateDataModel *m_model = nullptr;
};

#endif // CLIMATEDATAMODEL_H
