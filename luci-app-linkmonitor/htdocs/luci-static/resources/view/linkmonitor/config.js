'use strict';
'require view';
'require form';
'require uci';

return view.extend({
	title: _('Link Monitor - Configuration'),
	load: function() { return uci.load('linkmonitor'); },
	render: function() {
		var m, s, o;
		m = new form.Map('linkmonitor', _('Link Monitor Configuration'),
			_('Configure WAN interfaces to monitor, speed test settings, and alert rules including Telegram notifications.'));

		/* ===== Global Settings ===== */
		s = m.section(form.NamedSection, 'global', 'global', _('Global Settings'));
		s.anonymous = false;

		o = s.option(form.Flag, 'enabled', _('Enable Monitoring'),
			_('Enable or disable the link monitoring daemon.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'interval', _('Check Interval (seconds)'),
			_('Default interval between link checks. Interfaces can override.'));
		o.datatype = 'uinteger';
		o.default = '30';
		o.placeholder = '30';

		o = s.option(form.Value, 'history_size', _('Event History Size'),
			_('Maximum number of link state events to keep.'));
		o.datatype = 'uinteger';
		o.default = '200';
		o.placeholder = '200';

		o = s.option(form.Flag, 'speed_enabled', _('Enable Speed Tests'),
			_('Enable periodic download/upload speed tests per interface.'));
		o.default = '0';

		o = s.option(form.Value, 'speed_interval', _('Speed Test Interval (seconds)'),
			_('Time between automatic speed tests. Recommended: 1800 (30min) or higher.'));
		o.datatype = 'uinteger';
		o.default = '1800';
		o.placeholder = '1800';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'download_url', _('Download Test URL'),
			_('URL of a file to download for speed testing (e.g. http://proof.ovh.net/files/10Mb.dat).'));
		o.placeholder = 'http://proof.ovh.net/files/10Mb.dat';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'upload_url', _('Upload Test URL'),
			_('URL accepting POST data for upload test (e.g. http://devnull-as-a-service.com/dev/null).'));
		o.placeholder = 'http://devnull-as-a-service.com/dev/null';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'upload_size', _('Upload Size (MB)'),
			_('Size of data to upload for speed test.'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.placeholder = '5';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'speed_history_size', _('Speed History Size'),
			_('Maximum number of speed test records to keep.'));
		o.datatype = 'uinteger';
		o.default = '500';
		o.placeholder = '500';
		o.depends('speed_enabled', '1');

		/* ===== Monitored Interfaces ===== */
		s = m.section(form.TableSection, 'interface', _('Monitored Interfaces'),
			_('Configure WAN interfaces to monitor. Each interface is checked independently.'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.addbtntitle = _('Add Interface');

		o = s.option(form.Flag, 'enabled', _('On'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'),
			_('Descriptive name for this interface.'));
		o.rmempty = false;
		o.placeholder = _('e.g. WAN');

		o = s.option(form.Value, 'ifname', _('Device'),
			_('Physical network device (e.g. eth1, lan5). Leave empty to auto-detect from UCI.'));
		o.placeholder = _('e.g. eth1');
		o.optional = true;

		o = s.option(form.Value, 'uci_iface', _('UCI Interface'),
			_('UCI network interface name (e.g. wan, secondwan). Used for device auto-detection.'));
		o.placeholder = _('e.g. wan');
		o.optional = true;

		o = s.option(form.Value, 'host', _('Host / URL'),
			_('Target to check (IP, hostname, or URL).'));
		o.rmempty = false;
		o.placeholder = _('e.g. 8.8.8.8');

		o = s.option(form.ListValue, 'method', _('Method'));
		o.value('ping', _('Ping'));
		o.value('http', _('HTTP/S'));
		o.value('dns', _('DNS'));
		o.default = 'ping';

		o = s.option(form.Value, 'interval', _('Interval'));
		o.datatype = 'uinteger';
		o.optional = true;
		o.placeholder = _('global');

		o = s.option(form.Value, 'timeout', _('Timeout'));
		o.datatype = 'uinteger';
		o.default = '5';

		o = s.option(form.Value, 'retries', _('Retries'));
		o.datatype = 'uinteger';
		o.default = '3';
		o.depends('method', 'ping');

		o = s.option(form.Flag, 'speed_test', _('Speed'),
			_('Enable speed tests on this interface.'));
		o.default = '0';
		o.editable = true;

		/* ===== Alert Rules ===== */
		s = m.section(form.TableSection, 'alert', _('Alert Rules'),
			_('Configure alert actions for link state changes and speed degradation.'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.addbtntitle = _('Add Alert');

		o = s.option(form.Flag, 'enabled', _('On'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'type', _('Type'));
		o.value('syslog', _('Syslog'));
		o.value('telegram', _('Telegram'));
		o.value('email', _('Email'));
		o.value('script', _('Script'));
		o.value('webhook', _('Webhook'));
		o.default = 'syslog';

		o = s.option(form.ListValue, 'trigger', _('Trigger'));
		o.value('both', _('Both'));
		o.value('down', _('Down Only'));
		o.value('up', _('Up Only'));
		o.default = 'both';

		/* Telegram options */
		o = s.option(form.Value, 'bot_token', _('Bot Token'),
			_('Telegram Bot API token from @BotFather.'));
		o.depends('type', 'telegram');
		o.optional = true;
		o.password = true;

		o = s.option(form.Value, 'chat_id', _('Chat ID'),
			_('Telegram chat/group ID for notifications.'));
		o.depends('type', 'telegram');
		o.optional = true;

		o = s.option(form.Flag, 'notify_speed', _('Speed Alerts'),
			_('Send alert when speed drops below threshold.'));
		o.depends('type', 'telegram');
		o.default = '0';

		o = s.option(form.Value, 'speed_threshold', _('Threshold (Mbps)'),
			_('Alert when download speed falls below this value.'));
		o.datatype = 'ufloat';
		o.depends('type', 'telegram');
		o.optional = true;
		o.placeholder = '10';

		/* Email options */
		o = s.option(form.Value, 'recipient', _('Email'));
		o.depends('type', 'email');
		o.optional = true;

		o = s.option(form.Value, 'subject_prefix', _('Prefix'));
		o.depends('type', 'email');
		o.optional = true;
		o.placeholder = '[LinkMonitor]';

		/* Script options */
		o = s.option(form.Value, 'path', _('Script Path'));
		o.depends('type', 'script');
		o.optional = true;

		/* Webhook options */
		o = s.option(form.Value, 'url', _('Webhook URL'));
		o.depends('type', 'webhook');
		o.optional = true;

		return m.render();
	}
});
