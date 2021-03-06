module.exports = exports = function(app) {
    app.get('/admin/balances', app.security.demand.admin, exports.index)
    app.get('/admin/balances/wallets', app.security.demand.admin, exports.wallets)
}

exports.wallets = function(req, res, next) {
    req.app.conn.read.get().query([
        'SELECT *',
        'FROM wallet'
    ].join('\n'), function(err, dr) {
        if (err) return next(err)
        res.send(dr.rows.map(function(row) {
            console.log("bal %s, curr %s", row.balance, row.currency_id)
            //row.balance = req.app.cache.formatCurrency(row.balance, row.currency_id)
            return row
        }))
    })
}

exports.index = function(req, res, next) {
    req.app.conn.read.get().query([
        'SELECT a.currency_id currency, a.type, SUM(a.balance) balance',
        'FROM account a',
        'INNER JOIN "currency_active_view" c ON a.currency_id = c.currency_id',
        'GROUP BY a.currency_id, a.type',
        'ORDER BY type, currency'
    ].join('\n'), function(err, dr) {
        if (err) return next(err)
        res.send(dr.rows.map(function(row) {
            row.balance = req.app.cache.formatCurrency(row.balance, row.currency)
            return row
        }))
    })
}
