'use strict';
'require view';
'require dom';
'require poll';
'require rpc';
'require ui';

var callGetStatus = rpc.declare({
	object: 'linkmonitor', method: 'get_status', expect: { status: {} }
});
var callGetHistory = rpc.declare({
	object: 'linkmonitor', method: 'get_history', params: ['limit'], expect: { history: [] }
});
var callGetDaemonStatus = rpc.declare({
	object: 'linkmonitor', method: 'get_daemon_status', expect: {}
});
var callTestLink = rpc.declare({
	object: 'linkmonitor', method: 'test_link', params: ['host', 'method', 'timeout', 'ifname'], expect: {}
});
var callClearHistory = rpc.declare({
	object: 'linkmonitor', method: 'clear_history', expect: {}
});
var callRestartDaemon = rpc.declare({
	object: 'linkmonitor', method: 'restart_daemon', expect: {}
});
var callRunSpeedTest = rpc.declare({
	object: 'linkmonitor', method: 'run_speed_test', params: ['ifname', 'iface_name'], expect: {}
});

function formatTimeSince(ts) {
	if (!ts) return '-';
	var d = Math.floor(Date.now()/1000) - ts;
	if (d < 0) d = 0;
	if (d < 60) return d + 's ago';
	if (d < 3600) return Math.floor(d/60) + 'm ago';
	if (d < 86400) return Math.floor(d/3600) + 'h ago';
	return Math.floor(d/86400) + 'd ago';
}

function stateBadge(state) {
	var c = state === 'up' ? '#4caf50' : state === 'down' ? '#f44336' : '#9e9e9e';
	var l = state === 'up' ? 'UP' : state === 'down' ? 'DOWN' : 'UNKNOWN';
	return E('span', { style: 'display:inline-block;padding:2px 10px;border-radius:12px;color:#fff;font-weight:bold;font-size:12px;background:'+c }, l);
}

function latencyBar(lat) {
	var pct = Math.min((lat/500)*100, 100);
	var c = lat < 50 ? '#4caf50' : lat < 150 ? '#ff9800' : '#f44336';
	return E('div', { style: 'display:flex;align-items:center;gap:8px' }, [
		E('div', { style: 'flex:1;height:8px;background:#e0e0e0;border-radius:4px;overflow:hidden' }, [
			E('div', { style: 'height:100%;width:'+pct+'%;background:'+c+';border-radius:4px;transition:width .3s' })
		]),
		E('span', { style: 'font-size:12px;min-width:55px' }, lat + ' ms')
	]);
}

function speedBar(mbps, maxMbps, color) {
	maxMbps = maxMbps || 100;
	var pct = Math.min((mbps / maxMbps) * 100, 100);
	return E('div', { style: 'display:flex;align-items:center;gap:8px' }, [
		E('div', { style: 'flex:1;height:8px;background:#e0e0e0;border-radius:4px;overflow:hidden' }, [
			E('div', { style: 'height:100%;width:'+pct+'%;background:'+(color||'#2196f3')+';border-radius:4px;transition:width .3s' })
		]),
		E('span', { style: 'font-size:12px;min-width:70px;font-weight:bold' }, mbps.toFixed(2) + ' Mbps')
	]);
}

return view.extend({
	title: _('Link Monitor'),

	load: function() {
		return Promise.all([callGetStatus(), callGetHistory(50), callGetDaemonStatus()]);
	},

	render: function(data) {
		var status = data[0] || {}, history = (data[1] || []).reverse(), daemon = data[2] || {};
		var self = this;

		/* Daemon status bar */
		var daemonBar = E('div', {
			style: 'display:flex;align-items:center;gap:16px;padding:12px 16px;margin-bottom:16px;border-radius:8px;background:'+(daemon.running?'#e8f5e9':'#ffebee')+';border:1px solid '+(daemon.running?'#a5d6a7':'#ef9a9a')
		}, [
			E('span', { style: 'width:12px;height:12px;border-radius:50%;background:'+(daemon.running?'#4caf50':'#f44336') }),
			E('span', { style: 'font-weight:bold' }, daemon.running ? _('Daemon Running') : _('Daemon Stopped')),
			daemon.running ? E('span', { style: 'color:#666;font-size:13px' }, 'PID: '+(daemon.pid||0)) : '',
			E('div', { style: 'margin-left:auto' }, [
				E('button', { 'class': 'cbi-button cbi-button-action', click: function() {
					callRestartDaemon().then(function(r) {
						ui.addNotification(null, E('p', {}, r.result==='ok' ? _('Daemon restarted.') : _('Failed.')));
						window.setTimeout(function() { window.location.reload(); }, 1500);
					});
				}}, daemon.running ? _('Restart') : _('Start'))
			])
		]);

		/* Interface cards */
		var cards = [];
		var keys = Object.keys(status);
		if (!keys.length)
			cards.push(E('div', { style: 'padding:32px;text-align:center;color:#999' }, _('No interfaces configured. Go to Configuration to add interfaces.')));

		/* Find max speed for bar scaling */
		var maxDl = 1, maxUl = 1;
		for (var ki = 0; ki < keys.length; ki++) {
			var si = status[keys[ki]];
			if ((si.download || 0) > maxDl) maxDl = si.download;
			if ((si.upload || 0) > maxUl) maxUl = si.upload;
		}
		var maxSpeed = Math.max(maxDl, maxUl, 10);

		for (var i = 0; i < keys.length; i++) {
			var lk = status[keys[i]];
			var bc = lk.state==='up' ? '#4caf50' : lk.state==='down' ? '#f44336' : '#9e9e9e';
			var dl = parseFloat(lk.download) || 0;
			var ul = parseFloat(lk.upload) || 0;
			var hasSpeed = (dl > 0 || ul > 0);

			cards.push(E('div', {
				style: 'border:1px solid #ddd;border-left:4px solid '+bc+';border-radius:8px;padding:16px;margin-bottom:12px;background:#fff'
			}, [
				/* Header: name, interface, state, buttons */
				E('div', { style: 'display:flex;justify-content:space-between;align-items:center;margin-bottom:12px' }, [
					E('div', {}, [
						E('h3', { style: 'margin:0 0 4px 0;font-size:16px' }, lk.name || 'Interface '+(parseInt(keys[i])+1)),
						E('span', { style: 'color:#666;font-size:13px' }, [
							lk.host + ' (' + (lk.method||'ping') + ')',
							lk.ifname ? E('span', { style: 'margin-left:8px;padding:1px 6px;background:#e3f2fd;border-radius:4px;font-size:11px;color:#1565c0' }, lk.ifname) : '',
							lk.uci_iface ? E('span', { style: 'margin-left:4px;padding:1px 6px;background:#f3e5f5;border-radius:4px;font-size:11px;color:#7b1fa2' }, lk.uci_iface) : ''
						])
					]),
					E('div', { style: 'display:flex;align-items:center;gap:8px' }, [
						stateBadge(lk.state),
						E('button', { 'class': 'cbi-button cbi-button-action', style: 'font-size:12px;padding:2px 8px',
							'data-h': lk.host, 'data-m': lk.method||'ping', 'data-if': lk.ifname||'',
							click: function(ev) {
								var h=ev.target.getAttribute('data-h'), m=ev.target.getAttribute('data-m'), ifn=ev.target.getAttribute('data-if');
								ui.showModal(_('Testing'), [E('p', { 'class': 'spinning' }, _('Testing %s...').format(h))]);
								callTestLink(h, m, 5, ifn).then(function(r) {
									ui.hideModal();
									ui.showModal(_('Result'), [
										E('p', {}, [E('strong', {}, 'State: '), stateBadge(r.state||'unknown')]),
										E('p', {}, [E('strong', {}, 'Latency: '), (r.latency||0)+' ms']),
										r.packet_loss!==undefined ? E('p', {}, [E('strong', {}, 'Loss: '), r.packet_loss+'%']) : '',
										r.http_code!==undefined ? E('p', {}, [E('strong', {}, 'HTTP: '), String(r.http_code)]) : '',
										E('div', { 'class': 'right' }, [E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Close'))])
									]);
								});
							}
						}, _('Test')),
						lk.ifname ? E('button', { 'class': 'cbi-button cbi-button-action', style: 'font-size:12px;padding:2px 8px;background:#2196f3;border-color:#1976d2;color:#fff',
							'data-ifname': lk.ifname, 'data-iname': lk.name,
							click: function(ev) {
								var ifn=ev.target.getAttribute('data-ifname'), iname=ev.target.getAttribute('data-iname');
								ui.showModal(_('Speed Test'), [E('p', { 'class': 'spinning' }, _('Running speed test on %s (%s)... This may take up to 60 seconds.').format(iname, ifn))]);
								callRunSpeedTest(ifn, iname).then(function(r) {
									ui.hideModal();
									if (r.error) {
										ui.showModal(_('Error'), [E('p', {}, r.error), E('div', { 'class': 'right' }, [E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Close'))])]);
									} else {
										ui.showModal(_('Speed Test Result'), [
											E('p', {}, [E('strong', {}, 'Interface: '), (r.iface||iname) + ' (' + (r.ifname||ifn) + ')']),
											E('p', {}, [E('strong', {}, 'Download: '), E('span', { style: 'color:#2196f3;font-weight:bold' }, (r.download||0) + ' Mbps')]),
											E('p', {}, [E('strong', {}, 'Upload: '), E('span', { style: 'color:#ff9800;font-weight:bold' }, (r.upload||0) + ' Mbps')]),
											E('p', {}, [E('strong', {}, 'Latency: '), (r.latency||0) + ' ms']),
											E('div', { 'class': 'right' }, [E('button', { 'class': 'cbi-button', click: function() { ui.hideModal(); window.location.reload(); } }, _('Close'))])
										]);
									}
								});
							}
						}, _('Speed Test')) : ''
					])
				]),
				/* Stats grid */
				E('div', { style: 'display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px' }, [
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Latency')), latencyBar(lk.latency||0)]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Download')), speedBar(dl, maxSpeed, '#2196f3')]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Upload')), speedBar(ul, maxSpeed, '#ff9800')]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Last Check')), E('span', {}, formatTimeSince(lk.last_check))]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Last Change')), E('span', {}, formatTimeSince(lk.last_change))]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Fails')), E('span', { style: 'font-weight:bold;color:'+((lk.consecutive_fails>0)?'#f44336':'#4caf50') }, String(lk.consecutive_fails||0))])
				]),
				/* Speed test timestamp */
				hasSpeed ? E('div', { style: 'margin-top:8px;font-size:11px;color:#999;text-align:right' }, _('Speed test: ') + formatTimeSince(lk.speed_timestamp)) : ''
			]));
		}

		/* History table */
		var hrows = [];
		for (var j = 0; j < history.length && j < 50; j++) {
			var ev = history[j];
			hrows.push(E('tr', {}, [
				E('td', { style: 'padding:6px 12px' }, ev.time||'-'),
				E('td', { style: 'padding:6px 12px' }, ev.name||'-'),
				E('td', { style: 'padding:6px 12px' }, ev.host||'-'),
				E('td', { style: 'padding:6px 12px' }, ev.ifname ? E('span', { style: 'padding:1px 6px;background:#e3f2fd;border-radius:4px;font-size:11px;color:#1565c0' }, ev.ifname) : '-'),
				E('td', { style: 'padding:6px 12px' }, stateBadge(ev.state)),
				E('td', { style: 'padding:6px 12px' }, (ev.latency||0)+' ms')
			]));
		}

		return E('div', {}, [
			E('h2', {}, _('Link Monitor - Overview')),
			daemonBar,
			E('h3', { style: 'margin-top:24px' }, _('Monitored Interfaces')),
			E('div', {}, cards),
			E('div', { style: 'display:flex;justify-content:space-between;align-items:center;margin-top:24px' }, [
				E('h3', { style: 'margin:0' }, _('Event History')),
				E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
					ui.showModal(_('Clear History'), [
						E('p', {}, _('Clear all monitoring history?')),
						E('div', { 'class': 'right' }, [
							E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Cancel')), ' ',
							E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
								ui.hideModal(); callClearHistory().then(function() { window.location.reload(); });
							}}, _('Clear'))
						])
					]);
				}}, _('Clear History'))
			]),
			E('div', { style: 'margin-top:8px;overflow-x:auto' },
				E('table', { 'class': 'table', style: 'width:100%;border-collapse:collapse' }, [
					E('thead', {}, [E('tr', { style: 'background:#f5f5f5' }, [
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Time')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Interface')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Host')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Device')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('State')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Latency'))
					])]),
					E('tbody', {}, hrows.length ? hrows : [E('tr', {}, [E('td', { colspan: '6', style: 'padding:16px;text-align:center;color:#999' }, _('No events yet.'))])])
				])
			)
		]);
	},

	handleSaveApply: null, handleSave: null, handleReset: null
});
