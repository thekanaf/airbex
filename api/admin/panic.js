module.exports = exports = function(app) {
    app.post('/admin/panic', app.security.demand.admin, exports.panic)
}

exports.panic = function(req, res, next) {
    req.app.conn.write.get().query([
        'ALTER DATABASE justcoin',
        'SET default_transaction_read_only = true;'
    ].join('\n'), function(err) {
        if (err) {
            if (err.message.match(/in a read-only transaction/)) {
                return res.send(409, {
                    name: 'AlreadyReadOnly',
                    message: 'Database is already read only'
                })
            }

            return next(err)
        }

        req.app.conn.write.get().query([
            'SET TRANSACTION read write;',
            'SELECT pg_terminate_backend(pid)',
            'FROM pg_stat_activity;'
        ].join('\n'), function(err) {
            if (err) {
                if (err.message.match(/terminating connection/)) {
                    return res.status(204).end()
                }

                return next(err)
            }

            res.status(204).end()
        })
    })
}
