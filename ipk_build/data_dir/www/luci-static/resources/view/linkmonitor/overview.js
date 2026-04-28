'use strict';
'require view';
'require dom';
'require poll';
'require rpc';
'require ui';

var callGetStatus = rpc.declare({
	object: 'linkmonitor',
	method: 'get_status',
	expect: { status: {} }
});

var callGetHistory = rpc.declare({
	object: 'linkmonitor',
	method: 'get_history',
	params: ['limit'],
	expect: { history: [] }
});

var callGetDaemonStatus = rpc.declare({
	object: 'linkmonitor',
	method: 'get_daemon_status',
	expect: {}
});

var callTestLink = rpc.declare({
	object: 'linkmonitor',
	method: 'test_link',
	params: ['host', 'method', 'timeout'],
	expect: {}
});

var callClearHistory = rpc.declare({
	object: 'linkmonitor',
	method: 'clear_history',
	expect: {}
});

var callRestartDaemon = rpc.declare({
	object: 'linkmonitor',
	method: 'restart_daemon',
	expect: {}
});

function formatUptime(seconds) {
	if (!seconds || seconds <= 0) return '-';
	var d = Math.floor(seconds / 86400);
	var h = Math.floor((seconds % 86400) / 3600);
	var m = Math.floor((seconds % 3600) / 60);
	var s = seconds % 60;
	var parts = [];
	if (d > 0) parts.push(d + 'd');
	if (h > 0) parts.push(h + 'h');
	if (m > 0) parts.push(m + 'm');
	if (parts.length === 0) parts.push(s + 's');
	return parts.join(' ');
}

function formatTimeSince(timestamp) {
	if (!timestamp) return '-';
	var now = Math.floor(Date.now() / 1000);
	var diff = now - timestamp;
	if (diff < 60) return diff + 's ago';
	if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
	if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
	return Math.floor(diff / 86400) + 'd ago';
}

function stateColor(state) {
	switch (state) {
		case 'up': return '#4caf50';
		case 'down': return '#f44336';
		default: return '#9e9e9e';
	}
}

function stateBadge(state) {
	var color = stateColor(state);
	var label = (state === 'up') ? _('UP') : (state === 'down') ? _('DOWN') : _('UNKNOWN');
	return E('span', {
		'style': 'display:inline-block;padding:2px 10px;border-radius:12px;color:#fff;font-weight:bold;font-size:12px;background-color:' + color
	}, label);
}

function latencyBar(latency, max) {
	max = max || 500;
	var pct = Math.min((latency / max) * 100, 100);
	var color = latency < 50 ? '#4caf50' : latency < 150 ? '#ff9800' : '#f44336';
	return E('div', { 'style': 'display:flex;align-items:center;gap:8px;' }, [
		E('div', {
			'style': 'flex:1;height:8px;background:#e0e0e0;border-radius:4px;overflow:hidden;'
		}, [
			E('div', {
				'style': 'height:100%;width:' + pct + '%;background:' + color + ';border-radius:4px;transition:width 0.3s;'
			})
		]),
		E('span', { 'style': 'font-size:12px;min-width:60px;' }, latency + ' ms')
	]);
}

return view.extend({
	title: _('Link Monitor'),

	handleTestLink: function(host, method) {
		var self = this;
		return ui.showModal(_('Testing Link'), [
			E('p', { 'class': 'spinning' }, _('Testing %s...').format(host))
		]).then(function() {
			return callTestLink(host, method || 'ping', 5);
		}).then(function(result) {
			ui.hideModal();
			var msg = [];
			msg.push(E('p', {}, [
				E('strong', {}, _('Host') + ': '),
				result.host || host
			]));
			msg.push(E('p', {}, [
				E('strong', {}, _('State') + ': '),
				stateBadge(result.state || 'unknown')
			]));
			msg.push(E('p', {}, [
				E('strong', {}, _('Latency') + ': '),
				(result.latency || 0) + ' ms'
			]));
			if (result.packet_loss !== undefined) {
				msg.push(E('p', {}, [
					E('strong', {}, _('Packet Loss') + ': '),
					result.packet_loss + '%'
				]));
			}
			if (result.http_code !== undefined) {
				msg.push(E('p', {}, [
					E('strong', {}, _('HTTP Code') + ': '),
					result.http_code
				]));
			}
			ui.showModal(_('Test Result'), [
				E('div', {}, msg),
				E('div', { 'class': 'right' }, [
					E('button', { 'class': 'cbi-button', 'click': ui.hideModal }, _('Close'))
				])
			]);
		}).catch(function(err) {
			ui.hideModal();
			ui.addNotification(null, E('p', {}, _('Test failed: %s').format(err.message)));
		});
	},

	handleClearHistory: function() {
		return ui.showModal(_('Clear History'), [
			E('p', {}, _('Are you sure you want to clear all monitoring history?')),
			E('div', { 'class': 'right' }, [
				E('button', { 'class': 'cbi-button', 'click': ui.hideModal }, _('Cancel')),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-negative',
					'click': function() {
						ui.hideModal();
						callClearHistory().then(function() {
							ui.addNotification(null, E('p', {}, _('History cleared.')));
							window.location.reload();
						});
					}
				}, _('Clear'))
			])
		]);
	},

	handleRestartDaemon: function() {
		return callRestartDaemon().then(function(res) {
			if (res.result === 'ok')
				ui.addNotification(null, E('p', {}, _('Daemon restarted successfully.')));
			else
				ui.addNotification(null, E('p', {}, _('Failed to restart daemon.')));
		});
	},

	load: function() {
		return Promise.all([
			callGetStatus(),
			callGetHistory(50),
			callGetDaemonStatus()
		]);
	},

	render: function(data) {
		var status = data[0] || {};
		var history = (data[1] || []).reverse();
		var daemon = data[2] || {};
		var self = this;

		/* Daemon status bar */
		var daemonInfo = E('div', {
			'style': 'display:flex;align-items:center;gap:16px;padding:12px 16px;margin-bottom:16px;border-radius:8px;background:' +
				(daemon.running ? '#e8f5e9' : '#ffebee') + ';border:1px solid ' +
				(daemon.running ? '#a5d6a7' : '#ef9a9a')
		}, [
			E('span', {
				'style': 'width:12px;height:12px;border-radius:50%;background:' +
					(daemon.running ? '#4caf50' : '#f44336')
			}),
			E('span', { 'style': 'font-weight:bold;' },
				daemon.running ? _('Daemon Running') : _('Daemon Stopped')
			),
			daemon.running ? E('span', { 'style': 'color:#666;font-size:13px;' },
				_('PID: %d | Uptime: %s').format(daemon.pid || 0, formatUptime(daemon.uptime))
			) : '',
			E('div', { 'style': 'margin-left:auto;' }, [
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': L.bind(this.handleRestartDaemon, this)
				}, daemon.running ? _('Restart') : _('Start'))
			])
		]);

		/* Link status cards */
		var linkCards = [];
		var linkKeys = Object.keys(status);

		if (linkKeys.length === 0) {
			linkCards.push(E('div', {
				'style': 'padding:32px;text-align:center;color:#999;'
			}, _('No links configured. Go to Configuration to add links.')));
		}

		for (var i = 0; i < linkKeys.length; i++) {
			var key = linkKeys[i];
			var link = status[key];
			var borderColor = stateColor(link.state);

			var card = E('div', {
				'style': 'border:1px solid #ddd;border-left:4px solid ' + borderColor +
					';border-radius:8px;padding:16px;margin-bottom:12px;background:#fff;'
			}, [
				E('div', { 'style': 'display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;' }, [
					E('div', {}, [
						E('h3', { 'style': 'margin:0 0 4px 0;font-size:16px;' }, link.name || _('Link %d').format(parseInt(key) + 1)),
						E('span', { 'style': 'color:#666;font-size:13px;' }, link.host + ' (' + (link.method || 'ping') + ')')
					]),
					E('div', { 'style': 'display:flex;align-items:center;gap:8px;' }, [
						stateBadge(link.state),
						E('button', {
							'class': 'cbi-button cbi-button-action',
							'style': 'font-size:12px;padding:2px 8px;',
							'data-host': link.host,
							'data-method': link.method || 'ping',
							'click': function(ev) {
								var h = ev.target.getAttribute('data-host');
								var m = ev.target.getAttribute('data-method');
								self.handleTestLink(h, m);
							}
						}, _('Test'))
					])
				]),
				E('div', { 'style': 'display:grid;grid-template-columns:1fr 1fr;gap:8px;' }, [
					E('div', {}, [
						E('div', { 'style': 'font-size:12px;color:#999;margin-bottom:4px;' }, _('Latency')),
						latencyBar(link.latency || 0)
					]),
					E('div', {}, [
						E('div', { 'style': 'font-size:12px;color:#999;margin-bottom:4px;' }, _('Last Check')),
						E('span', { 'style': 'font-size:14px;' }, formatTimeSince(link.last_check))
					]),
					E('div', {}, [
						E('div', { 'style': 'font-size:12px;color:#999;margin-bottom:4px;' }, _('Last State Change')),
						E('span', { 'style': 'font-size:14px;' }, formatTimeSince(link.last_change))
					]),
					E('div', {}, [
						E('div', { 'style': 'font-size:12px;color:#999;margin-bottom:4px;' }, _('Consecutive Fails')),
						E('span', {
							'style': 'font-size:14px;font-weight:bold;color:' +
								((link.consecutive_fails > 0) ? '#f44336' : '#4caf50')
						}, String(link.consecutive_fails || 0))
					])
				])
			]);

			linkCards.push(card);
		}

		/* History table */
		var historyRows = [];
		for (var j = 0; j < history.length && j < 50; j++) {
			var evt = history[j];
			historyRows.push(E('tr', {}, [
				E('td', { 'style': 'padding:6px 12px;' }, evt.time || '-'),
				E('td', { 'style': 'padding:6px 12px;' }, evt.name || '-'),
				E('td', { 'style': 'padding:6px 12px;' }, evt.host || '-'),
				E('td', { 'style': 'padding:6px 12px;' }, stateBadge(evt.state)),
				E('td', { 'style': 'padding:6px 12px;' }, (evt.latency || 0) + ' ms')
			]));
		}

		var historyTable = E('table', {
			'class': 'table',
			'style': 'width:100%;border-collapse:collapse;'
		}, [
			E('thead', {}, [
				E('tr', { 'style': 'background:#f5f5f5;' }, [
					E('th', { 'style': 'padding:8px 12px;text-align:left;' }, _('Time')),
					E('th', { 'style': 'padding:8px 12px;text-align:left;' }, _('Link')),
					E('th', { 'style': 'padding:8px 12px;text-align:left;' }, _('Host')),
					E('th', { 'style': 'padding:8px 12px;text-align:left;' }, _('State')),
					E('th', { 'style': 'padding:8px 12px;text-align:left;' }, _('Latency'))
				])
			]),
			E('tbody', {}, historyRows.length > 0 ? historyRows : [
				E('tr', {}, [
					E('td', { 'colspan': '5', 'style': 'padding:16px;text-align:center;color:#999;' },
						_('No history events yet.'))
				])
			])
		]);

		var view = E('div', {}, [
			E('h2', {}, _('Link Monitor - Overview')),
			daemonInfo,

			E('h3', { 'style': 'margin-top:24px;' }, _('Monitored Links')),
			E('div', {}, linkCards),

			E('div', {
				'style': 'display:flex;justify-content:space-between;align-items:center;margin-top:24px;'
			}, [
				E('h3', { 'style': 'margin:0;' }, _('Event History')),
				E('button', {
					'class': 'cbi-button cbi-button-negative',
					'click': L.bind(this.handleClearHistory, this)
				}, _('Clear History'))
			]),
			E('div', { 'style': 'margin-top:8px;overflow-x:auto;' }, historyTable)
		]);

		/* Set up polling for real-time updates */
		poll.add(L.bind(function() {
			return Promise.all([
				callGetStatus(),
				callGetDaemonStatus()
			]).then(L.bind(function(pollData) {
				// Update will trigger on next full render via poll
			}, this));
		}, this), 10);

		return view;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
