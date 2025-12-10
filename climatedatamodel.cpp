#include "climatedatamodel.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFile>
#include <algorithm>
#include <cmath>

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

QVector4D ClimateDataModel::getPoint(int index) const
{
    if (index < 0 || index >= m_dataPoints.size()) {
        return QVector4D(0, 0, 0, 0);
    }

    const ClimateDataPoint &point = m_dataPoints[index];
    double normalizedValue = normalizeValue(getRawValue(index));

    return QVector4D(
        static_cast<float>(point.lat),
        static_cast<float>(point.lon),
        static_cast<float>(normalizedValue),
        0.0f
    );
}

double ClimateDataModel::getRawValue(int index) const
{
    if (index < 0 || index >= m_dataPoints.size()) {
        return 0.0;
    }

    const ClimateDataPoint &point = m_dataPoints[index];

    if (m_activeColumn == "TAMB_Mean") {
        return point.tambMean;
    } else if (m_activeColumn == "TAMB_Delta") {
        return point.tambDelta;
    }

    return 0.0;
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
            ClimateDataPoint point;
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

    calculateMinMax();
    emit dataChanged();

    return true;
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

double ClimateDataModel::normalizeValue(double value) const
{
    if (std::abs(m_maxValue - m_minValue) < 0.0001) {
        return 0.5;
    }
    return (value - m_minValue) / (m_maxValue - m_minValue);
}
