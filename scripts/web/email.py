#!/usr/bin/env python3
"""
Substrate Email Client — Send outreach emails via SMTP.

Usage:
    # Send a single email
    python3 email.py send --to "editor@techsite.com" --subject "Subject" --body "Body text"

    # Send from a template file
    python3 email.py send --to "editor@techsite.com" --template press-release.txt

    # Send to a list (CSV: name,email,outlet)
    python3 email.py blast --list contacts.csv --template press-release.txt --dry-run
    python3 email.py blast --list contacts.csv --template press-release.txt

    # Test SMTP connection
    python3 email.py test

Environment variables (required):
    SMTP_HOST     — SMTP server (e.g., smtp.gmail.com)
    SMTP_PORT     — SMTP port (default: 587)
    SMTP_USER     — SMTP username/email
    SMTP_PASS     — SMTP password or app password
    SMTP_FROM     — From address (defaults to SMTP_USER)

Templates support placeholders: {name}, {outlet}, {date}, {game_count}, {post_count}
"""

import argparse
import csv
import json
import os
import smtplib
import ssl
import sys
import time
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path


def get_smtp_config():
    """Load SMTP config from environment."""
    host = os.environ.get('SMTP_HOST')
    port = int(os.environ.get('SMTP_PORT', '587'))
    user = os.environ.get('SMTP_USER')
    password = os.environ.get('SMTP_PASS')
    from_addr = os.environ.get('SMTP_FROM', user)

    if not all([host, user, password]):
        print('ERROR: Set SMTP_HOST, SMTP_USER, and SMTP_PASS environment variables.')
        print('Example:')
        print('  export SMTP_HOST=smtp.gmail.com')
        print('  export SMTP_USER=substrate@operator.dev')
        print('  export SMTP_PASS=your-app-password')
        sys.exit(1)

    return {
        'host': host,
        'port': port,
        'user': user,
        'password': password,
        'from': from_addr,
    }


def fill_template(template, context):
    """Replace {placeholders} in template with context values."""
    result = template
    for key, value in context.items():
        result = result.replace('{' + key + '}', str(value))
    return result


def send_email(config, to_addr, subject, body, html_body=None, dry_run=False):
    """Send a single email via SMTP."""
    msg = MIMEMultipart('alternative')
    msg['From'] = config['from']
    msg['To'] = to_addr
    msg['Subject'] = subject
    msg['Reply-To'] = config['from']

    # Plain text part
    msg.attach(MIMEText(body, 'plain'))

    # HTML part (optional)
    if html_body:
        msg.attach(MIMEText(html_body, 'html'))

    if dry_run:
        print(f'[DRY RUN] Would send to: {to_addr}')
        print(f'  Subject: {subject}')
        print(f'  Body preview: {body[:120]}...')
        return True

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP(config['host'], config['port']) as server:
            server.starttls(context=context)
            server.login(config['user'], config['password'])
            server.sendmail(config['from'], to_addr, msg.as_string())
        print(f'[SENT] {to_addr} — {subject}')
        return True
    except Exception as e:
        print(f'[ERROR] {to_addr} — {e}')
        return False


def cmd_test(args):
    """Test SMTP connection."""
    config = get_smtp_config()
    print(f'Testing SMTP connection to {config["host"]}:{config["port"]}...')
    try:
        context = ssl.create_default_context()
        with smtplib.SMTP(config['host'], config['port']) as server:
            server.starttls(context=context)
            server.login(config['user'], config['password'])
            print('SUCCESS — SMTP connection and login OK.')
    except Exception as e:
        print(f'FAILED — {e}')
        sys.exit(1)


def cmd_send(args):
    """Send a single email."""
    config = get_smtp_config()

    subject = args.subject
    body = args.body

    if args.template:
        template_path = Path(args.template)
        if not template_path.exists():
            print(f'ERROR: Template not found: {args.template}')
            sys.exit(1)
        content = template_path.read_text()
        # First line is subject if template starts with "Subject: "
        lines = content.split('\n')
        if lines[0].startswith('Subject:'):
            subject = lines[0].replace('Subject:', '').strip()
            body = '\n'.join(lines[1:]).strip()
        else:
            body = content

    context = {
        'name': args.name or 'there',
        'outlet': args.outlet or '',
        'date': datetime.now().strftime('%B %d, %Y'),
        'game_count': '9',
        'post_count': '24',
    }
    body = fill_template(body, context)
    if subject:
        subject = fill_template(subject, context)

    if not subject:
        print('ERROR: No subject provided. Use --subject or include "Subject:" in template.')
        sys.exit(1)

    send_email(config, args.to, subject, body, dry_run=args.dry_run)


def cmd_blast(args):
    """Send to a CSV list of contacts."""
    config = get_smtp_config()

    # Load template
    template_path = Path(args.template)
    if not template_path.exists():
        print(f'ERROR: Template not found: {args.template}')
        sys.exit(1)
    content = template_path.read_text()

    lines = content.split('\n')
    subject_template = ''
    body_template = content
    if lines[0].startswith('Subject:'):
        subject_template = lines[0].replace('Subject:', '').strip()
        body_template = '\n'.join(lines[1:]).strip()

    # Load contacts CSV (name,email,outlet)
    contacts_path = Path(args.list)
    if not contacts_path.exists():
        print(f'ERROR: Contact list not found: {args.list}')
        sys.exit(1)

    contacts = []
    with open(contacts_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            contacts.append(row)

    print(f'Loaded {len(contacts)} contacts from {args.list}')
    if args.dry_run:
        print('[DRY RUN MODE — no emails will actually be sent]')
    print()

    sent = 0
    failed = 0
    for contact in contacts:
        context = {
            'name': contact.get('name', 'there'),
            'email': contact.get('email', ''),
            'outlet': contact.get('outlet', ''),
            'date': datetime.now().strftime('%B %d, %Y'),
            'game_count': '9',
            'post_count': '24',
        }

        subject = fill_template(subject_template, context)
        body = fill_template(body_template, context)
        to = contact.get('email', '')

        if not to:
            print(f'[SKIP] No email for {contact.get("name", "?")}')
            continue

        ok = send_email(config, to, subject, body, dry_run=args.dry_run)
        if ok:
            sent += 1
        else:
            failed += 1

        # Rate limit: 2 second delay between real sends
        if not args.dry_run:
            time.sleep(2)

    print(f'\nDone. Sent: {sent}, Failed: {failed}, Total: {len(contacts)}')

    # Log the blast
    log_path = Path(__file__).parent.parent.parent / 'memory' / 'email-log.json'
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'template': args.template,
        'contacts': len(contacts),
        'sent': sent,
        'failed': failed,
        'dry_run': args.dry_run,
    }
    log = []
    if log_path.exists():
        try:
            log = json.loads(log_path.read_text())
        except Exception:
            pass
    log.append(log_entry)
    log_path.write_text(json.dumps(log, indent=2))


def main():
    parser = argparse.ArgumentParser(description='Substrate Email Client')
    sub = parser.add_subparsers(dest='command')

    # test
    sub.add_parser('test', help='Test SMTP connection')

    # send
    p_send = sub.add_parser('send', help='Send a single email')
    p_send.add_argument('--to', required=True, help='Recipient email')
    p_send.add_argument('--subject', help='Email subject')
    p_send.add_argument('--body', help='Email body text')
    p_send.add_argument('--template', help='Template file path')
    p_send.add_argument('--name', help='Recipient name for template')
    p_send.add_argument('--outlet', help='Recipient outlet/org for template')
    p_send.add_argument('--dry-run', action='store_true', help='Print without sending')

    # blast
    p_blast = sub.add_parser('blast', help='Send to a CSV contact list')
    p_blast.add_argument('--list', required=True, help='CSV file (name,email,outlet)')
    p_blast.add_argument('--template', required=True, help='Template file path')
    p_blast.add_argument('--dry-run', action='store_true', help='Print without sending')

    args = parser.parse_args()

    if args.command == 'test':
        cmd_test(args)
    elif args.command == 'send':
        cmd_send(args)
    elif args.command == 'blast':
        cmd_blast(args)
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
