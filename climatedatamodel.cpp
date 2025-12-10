#include "climatedatamodel.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFile>
#include <algorithm>
#include <cmath>
#include <set>

ClimateDataModel::ClimateDataModel(QObject *parent)
    : QObject(parent)
{
}

QString ClimateDataModel::databasePath() const
{
    return m_databasePath;
}

void ClimateDataModel::setDatabasePath(const QString &path)
{
    if (m_databasePath != path) {
        m_databasePath = path;
        emit databasePathChanged();
        loadData();
    }
}

QString ClimateDataModel::activeColumn() const
{
    return m_activeColumn;
}

void ClimateDataModel::setActiveColumn(const QString &column)
{
    if (m_activeColumn != column && availableColumns().contains(column)) {
        m_activeColumn = column;
        calculateMinMax();
        generateTexture();
        emit activeColumnChanged();
        emit dataChanged();
    }
}

int ClimateDataModel::pointCount() const
{
    return m_dataPoints.size();
}

QStringList ClimateDataModel::availableColumns() const
{
    return {"TAMB_Mean", "TAMB_Delta"};
}

double ClimateDataModel::minValue() const
{
    return m_minValue;
}

double ClimateDataModel::maxValue() const
{
    return m_maxValue;
}

int ClimateDataModel::textureWidth() const
{
    return m_textureWidth;
}

int ClimateDataModel::textureHeight() const
{
    return m_textureHeight;
}

double ClimateDataModel::gridResolution() const
{
    return m_gridResolution;
}

QImage ClimateDataModel::dataTexture() const
{
    return m_dataTexture;
}

bool ClimateDataModel::loadData()
{
    if (m_databasePath.isEmpty()) {
        qWarning() << "Database path is empty";
        return false;
    }

    // Handle file:// URLs
    QString dbPath = m_databasePath;
    if (dbPath.startsWith("file://")) {
        dbPath = dbPath.mid(7);
    }

    if (!QFile::exists(dbPath)) {
        qWarning() << "Database file does not exist:" << dbPath;
        return false;
    }

    // Use a unique connection name to avoid conflicts
    QString connectionName = QString("climate_db_%1").arg(reinterpret_cast<quintptr>(this));

    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connectionName);
        db.setDatabaseName(dbPath);

        if (!db.open()) {
            qWarning() << "Failed to open database:" << db.lastError().text();
            return false;
        }

        m_dataPoints.clear();

        QSqlQuery query(db);
        if (!query.exec("SELECT lat, lon, TAMB_Mean, TAMB_Delta FROM Climate_data")) {
            qWarning() << "Query failed:" << query.lastError().text();
            db.close();
            return false;
        }

        while (query.next()) {
            DataPoint point;
            point.lat = query.value(0).toDouble();
            point.lon = query.value(1).toDouble();
            point.tambMean = query.value(2).toDouble();
            point.tambDelta = query.value(3).toDouble();
            m_dataPoints.append(point);
        }

        db.close();
    }

    QSqlDatabase::removeDatabase(connectionName);

    qDebug() << "Loaded" << m_dataPoints.size() << "climate data points";

    // Detect grid resolution from data
    detectGridResolution();

    // Calculate min/max for normalization
    calculateMinMax();

    // Generate the texture
    generateTexture();

    emit dataChanged();

    return true;
}

void ClimateDataModel::detectGridResolution()
{
    if (m_dataPoints.size() < 2) {
        return;
    }

    // Find min/max lat/lon
    m_minLat = std::numeric_limits<double>::max();
    m_maxLat = std::numeric_limits<double>::lowest();
    m_minLon = std::numeric_limits<double>::max();
    m_maxLon = std::numeric_limits<double>::lowest();

    // Collect unique lat/lon values to detect grid spacing
    std::set<double> latValues;
    std::set<double> lonValues;

    for (const auto &point : m_dataPoints) {
        m_minLat = std::min(m_minLat, point.lat);
        m_maxLat = std::max(m_maxLat, point.lat);
        m_minLon = std::min(m_minLon, point.lon);
        m_maxLon = std::max(m_maxLon, point.lon);

        latValues.insert(point.lat);
        lonValues.insert(point.lon);
    }

    // Detect resolution by finding minimum difference between sorted values
    if (latValues.size() > 1) {
        auto it = latValues.begin();
        double prev = *it++;
        double minDiff = std::numeric_limits<double>::max();
        while (it != latValues.end()) {
            double diff = *it - prev;
            if (diff > 0.001) {  // Ignore tiny differences due to floating point
                minDiff = std::min(minDiff, diff);
            }
            prev = *it++;
        }
        if (minDiff < std::numeric_limits<double>::max()) {
            m_gridResolution = minDiff;
        }
    }

    // Calculate texture dimensions based on data bounds and resolution
    double latRange = m_maxLat - m_minLat;
    double lonRange = m_maxLon - m_minLon;

    m_textureHeight = static_cast<int>(std::round(latRange / m_gridResolution)) + 1;
    m_textureWidth = static_cast<int>(std::round(lonRange / m_gridResolution)) + 1;

    // Limit texture size to reasonable bounds
    m_textureWidth = std::min(m_textureWidth, 4096);
    m_textureHeight = std::min(m_textureHeight, 2048);

    qDebug() << "Grid resolution:" << m_gridResolution << "degrees";
    qDebug() << "Lat range:" << m_minLat << "to" << m_maxLat;
    qDebug() << "Lon range:" << m_minLon << "to" << m_maxLon;
    qDebug() << "Texture size:" << m_textureWidth << "x" << m_textureHeight;
}

void ClimateDataModel::calculateMinMax()
{
    if (m_dataPoints.isEmpty()) {
        m_minValue = 0.0;
        m_maxValue = 1.0;
        return;
    }

    m_minValue = std::numeric_limits<double>::max();
    m_maxValue = std::numeric_limits<double>::lowest();

    for (const auto &point : m_dataPoints) {
        double value = 0.0;
        if (m_activeColumn == "TAMB_Mean") {
            value = point.tambMean;
        } else if (m_activeColumn == "TAMB_Delta") {
            value = point.tambDelta;
        }

        m_minValue = std::min(m_minValue, value);
        m_maxValue = std::max(m_maxValue, value);
    }

    qDebug() << "Column:" << m_activeColumn << "Min:" << m_minValue << "Max:" << m_maxValue;
}

void ClimateDataModel::generateTexture()
{
    if (m_dataPoints.isEmpty() || m_textureWidth <= 0 || m_textureHeight <= 0) {
        m_dataTexture = QImage();
        return;
    }

    // Create texture with RGBA format
    // We store normalized value in all channels for easy sampling
    m_dataTexture = QImage(m_textureWidth, m_textureHeight, QImage::Format_RGBA8888);
    m_dataTexture.fill(Qt::transparent);  // Default to transparent (no data)

    // Fill texture with data points
    for (const auto &point : m_dataPoints) {
        int x = lonToTextureX(point.lon);
        int y = latToTextureY(point.lat);

        if (x >= 0 && x < m_textureWidth && y >= 0 && y < m_textureHeight) {
            double value = 0.0;
            if (m_activeColumn == "TAMB_Mean") {
                value = point.tambMean;
            } else if (m_activeColumn == "TAMB_Delta") {
                value = point.tambDelta;
            }

            double normalized = normalizeValue(value);
            int pixelValue = static_cast<int>(normalized * 255.0);

            // Store normalized value in R channel, full alpha to indicate valid data
            m_dataTexture.setPixelColor(x, y, QColor(pixelValue, pixelValue, pixelValue, 255));
        }
    }

    qDebug() << "Generated texture:" << m_textureWidth << "x" << m_textureHeight;
}

double ClimateDataModel::normalizeValue(double value) const
{
    if (std::abs(m_maxValue - m_minValue) < 0.0001) {
        return 0.5;
    }
    return std::clamp((value - m_minValue) / (m_maxValue - m_minValue), 0.0, 1.0);
}

int ClimateDataModel::latToTextureY(double lat) const
{
    // Latitude: top of image is max lat, bottom is min lat
    double normalized = (m_maxLat - lat) / (m_maxLat - m_minLat);
    return static_cast<int>(std::round(normalized * (m_textureHeight - 1)));
}

int ClimateDataModel::lonToTextureX(double lon) const
{
    // Longitude: left is min lon, right is max lon
    double normalized = (lon - m_minLon) / (m_maxLon - m_minLon);
    return static_cast<int>(std::round(normalized * (m_textureWidth - 1)));
}

// ClimateTextureProvider implementation
ClimateTextureProvider::ClimateTextureProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

void ClimateTextureProvider::setModel(ClimateDataModel *model)
{
    m_model = model;
}

QImage ClimateTextureProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    Q_UNUSED(id);
    Q_UNUSED(requestedSize);

    if (!m_model) {
        if (size) *size = QSize(1, 1);
        return QImage(1, 1, QImage::Format_RGBA8888);
    }

    QImage texture = m_model->dataTexture();
    if (texture.isNull()) {
        if (size) *size = QSize(1, 1);
        return QImage(1, 1, QImage::Format_RGBA8888);
    }

    if (size) {
        *size = texture.size();
    }

    return texture;
}
