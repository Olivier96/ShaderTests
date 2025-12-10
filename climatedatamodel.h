#ifndef CLIMATEDATAMODEL_H
#define CLIMATEDATAMODEL_H

#include <QObject>
#include <QAbstractListModel>
#include <QVector4D>
#include <QtQml/qqmlregistration.h>

struct ClimateDataPoint {
    double lat;
    double lon;
    double tambMean;
    double tambDelta;
};

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

    // Get normalized value (0-1) for a point based on active column
    Q_INVOKABLE QVector4D getPoint(int index) const;

    // Get raw value for a point
    Q_INVOKABLE double getRawValue(int index) const;

    // Load data from the database
    Q_INVOKABLE bool loadData();

signals:
    void databasePathChanged();
    void activeColumnChanged();
    void dataChanged();

private:
    void calculateMinMax();
    double normalizeValue(double value) const;

    QString m_databasePath;
    QString m_activeColumn = "TAMB_Mean";
    QVector<ClimateDataPoint> m_dataPoints;
    double m_minValue = 0.0;
    double m_maxValue = 1.0;
};

#endif // CLIMATEDATAMODEL_H
