#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <qqmlintegration.h>

class OpenFoodFactsFetcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isLoading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(QString lastStatus READ lastStatus NOTIFY statusChanged)

public:
    explicit OpenFoodFactsFetcher(QObject *parent = nullptr);

    bool isLoading() const { return m_isLoading; }
    QString lastStatus() const { return m_lastStatus; }

    Q_INVOKABLE void lookupBarcode(const QString &barcode);
    Q_INVOKABLE void search(const QString &query);

private:
    QVariantMap resolveLocalPresetOrDb(const QString &barcode);

signals:
    void loadingChanged();
    void statusChanged();
    void barcodeFound(const QVariantMap &product);
    void searchCompleted(const QVariantList &results);
    void fetchError(const QString &message);

private slots:
    void handleBarcodeReply(QNetworkReply *reply);
    void handleSearchReply(QNetworkReply *reply);

private:
    QNetworkRequest createRequest(const QUrl &url);
    QVariantMap parseProductJson(const QJsonObject &obj);

    QNetworkAccessManager m_nam;
    bool m_isLoading = false;
    QString m_lastStatus;
};
