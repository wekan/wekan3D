#!/usr/bin/env python3
"""Extract uploaded Meteor SimpleSchema declarations without running JavaScript.

Usage: python tools/generate_schema.py /path/to/extracted/models
Only Python's standard library is required. Source code is input, not bundled.
"""
import ast
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def tokens(text):
    result = []
    i = 0
    while i < len(text):
        c = text[i]
        if c.isspace():
            i += 1
            continue
        if text.startswith('//', i):
            end = text.find('\n', i + 2)
            i = len(text) if end < 0 else end
            continue
        if text.startswith('/*', i):
            end = text.find('*/', i + 2)
            i = len(text) if end < 0 else end + 2
            continue
        start = i
        if c in "'\"`":
            i += 1
            while i < len(text):
                if text[i] == '\\':
                    i += 2
                elif text[i] == c:
                    i += 1
                    break
                else:
                    i += 1
        elif c == '/' and (not result or result[-1][0] in ['=', ':', '(', ',', '[', '!', 'return', '?', '=>']):
            i += 1
            in_class = False
            while i < len(text):
                if text[i] == '\\':
                    i += 2
                    continue
                if text[i] == '[':
                    in_class = True
                elif text[i] == ']':
                    in_class = False
                elif text[i] == '/' and not in_class:
                    i += 1
                    while i < len(text) and text[i].isalpha():
                        i += 1
                    break
                i += 1
        elif c.isalnum() or c in '_$':
            i += 1
            while i < len(text) and (text[i].isalnum() or text[i] in '_$'):
                i += 1
        else:
            i += 1
        result.append((text[start:i], start, i))
    return result


def matching(ts, start):
    pairs = {'{': '}', '[': ']', '(': ')'}
    stack = []
    for i in range(start, len(ts)):
        token = ts[i][0]
        if token in pairs:
            stack.append(pairs[token])
        elif token in ['}', ']', ')']:
            if not stack or stack.pop() != token:
                raise ValueError(f'Unbalanced JavaScript near {ts[i]}')
            if not stack:
                return i
    raise ValueError('Unterminated JavaScript delimiter')


def unquote(value):
    if value[:1] in ["'", '"']:
        try:
            return ast.literal_eval(value)
        except (ValueError, SyntaxError):
            return value[1:-1]
    return value


def object_entries(ts, start):
    """Return (literal property name, value tokens), skipping method bodies."""
    end = matching(ts, start)
    parts, part, i = [], start + 1, start + 1
    while i < end:
        if ts[i][0] in ['{', '[', '(']:
            i = matching(ts, i) + 1
            continue
        if ts[i][0] == ',':
            parts.append(ts[part:i])
            part = i + 1
        i += 1
    parts.append(ts[part:end])
    entries = {}
    for part in parts:
        if not part:
            continue
        key = unquote(part[0][0])
        if len(part) > 1 and part[1][0] == ':':
            entries[key] = part[2:]
        elif len(part) > 1 and part[1][0] == '(':
            entries[key] = part[1:]
    return entries


def raw(text, ts):
    return text[ts[0][1]:ts[-1][2]].strip() if ts else ''


def literal_value(value):
    if value in ['true', 'false', 'null']:
        return {'true': True, 'false': False, 'null': None}[value], True
    try:
        return ast.literal_eval(value), True
    except (ValueError, SyntaxError):
        return None, False


def schema_fields(text, ts, start, named_schemas, prefix=''):
    fields = {}
    for field, value_tokens in object_entries(ts, start).items():
        if not value_tokens or value_tokens[0][0] != '{':
            continue
        props = object_entries(value_tokens, 0)
        type_tokens = props.get('type', [])
        type_raw = raw(text, type_tokens)
        source_type = type_raw
        nested = None
        if len(type_tokens) >= 4 and [x[0] for x in type_tokens[:3]] == ['new', 'SimpleSchema', '(']:
            source_type = 'Object'
            nested = (type_tokens, 3)
        elif type_raw in named_schemas:
            source_type = 'Object'
            nested = named_schemas[type_raw]
        elif type_raw.startswith('['):
            source_type = 'Array'
        sqlite_type = {'String': 'TEXT', 'Boolean': 'INTEGER', 'Date': 'TEXT', 'Number': 'REAL', 'SimpleSchema.Integer': 'INTEGER'}.get(source_type, 'TEXT')
        descriptor = {
            'name': prefix + field, 'source_type': source_type,
            'sqlite_type': sqlite_type, 'type_expression': type_raw,
            'optional': raw(text, props.get('optional', [])) == 'true',
            'storage': 'json' if source_type in ['Object', 'Array'] or source_type.startswith('Match.OneOf') else 'scalar',
            'line': text.count('\n', 0, value_tokens[0][1]) + 1,
        }
        for prop in ['defaultValue', 'allowedValues', 'min', 'max', 'regEx', 'blackbox', 'autoValue', 'custom', 'decimal']:
            if prop in props:
                expression = raw(text, props[prop])
                if prop in ['autoValue', 'custom']:
                    descriptor[prop] = {'dynamic': True, 'executed': False}
                else:
                    value, is_literal = literal_value(expression)
                    descriptor[prop] = {'expression': expression, 'literal': is_literal}
                    if is_literal:
                        descriptor[prop]['value'] = value
        fields[prefix + field] = descriptor
        if nested:
            fields.update(schema_fields(text, nested[0], nested[1], named_schemas, prefix + field + '.'))
    return fields


def extract_source(path):
    text = path.read_text()
    ts = tokens(text)
    collections = {}
    aliases = {}
    for match in re.finditer(r'(?:const|let|var)\s+(\w+)\s*=\s*new\s+Mongo\.Collection\s*\(\s*([\'\"])([^\'\"]+)\2', text):
        aliases[match.group(1)] = match.group(3)
        collections[match.group(3)] = {'name': match.group(3), 'symbol': match.group(1), 'file': path.name, 'fields': {}, 'declaration': 'Mongo.Collection'}
    for match in re.finditer(r'(?:const|let|var)\s+(\w+)\s*=\s*Meteor\.users\b', text):
        aliases[match.group(1)] = 'users'
        collections['users'] = {'name': 'users', 'symbol': match.group(1), 'file': path.name, 'fields': {}, 'declaration': 'Meteor.users'}
    for match in re.finditer(r'(?:const|let|var)\s+(\w+)\s*=\s*new\s+FilesCollection\s*\(\s*\{', text):
        name_match = re.search(r'collectionName\s*:\s*([\'\"])([^\'\"]+)\1', text[match.end():])
        if name_match:
            name = name_match.group(2)
            aliases[match.group(1)] = name
            collections[name] = {'name': name, 'symbol': match.group(1), 'file': path.name, 'fields': {}, 'declaration': 'FilesCollection'}
    named_schemas = {}
    for i in range(len(ts) - 6):
        if ts[i][0] in ['const', 'let', 'var'] and [x[0] for x in ts[i + 2:i + 6]] == ['=', 'new', 'SimpleSchema', '('] and ts[i + 6][0] == '{':
            named_schemas[ts[i + 1][0]] = (ts, i + 6)
    attached = []
    for i in range(len(ts) - 5):
        if ts[i][0] not in aliases and ts[i][0] != 'collection':
            continue
        if [x[0] for x in ts[i + 1:i + 4]] != ['.', 'attachSchema', '(']:
            continue
        start = i + 4
        if [x[0] for x in ts[start:start + 3]] == ['new', 'SimpleSchema', '(']:
            start += 3
        if ts[start][0] != '{':
            raise ValueError(f'Unsupported attachSchema expression in {path.name}:{ts[start]}')
        fields = schema_fields(text, ts, start, named_schemas)
        if ts[i][0] == 'collection':
            attached.append(fields)
        else:
            collections[aliases[ts[i][0]]]['fields'].update(fields)
    for collection in collections.values():
        if not collection['fields']:
            collection['schema_status'] = 'schemaless: no SimpleSchema declaration in uploaded file'
            collection['fields']['document_json'] = {'name': 'document_json', 'source_type': 'Object', 'sqlite_type': 'TEXT', 'storage': 'json', 'optional': True, 'inferred': True, 'note': 'Preserves arbitrary fields; no invented required schema.'}
            # Record fields explicitly referenced in this schema-less model only.
            for match in re.finditer(r'\b(?:doc|this|fileObj)\.([A-Za-z_$][\w$]*)\b', text):
                field = match.group(1)
                if field in ['_id', 'field', 'isSet', 'isInsert', 'isUpdate', 'isUpsert', 'unset', 'setUserId']:
                    continue
                after = text[match.end():].lstrip()
                if after.startswith('('):
                    continue
                field_type = 'Date' if field.endswith('At') else 'String'
                collection['fields'].setdefault(field, {'name': field, 'source_type': field_type, 'sqlite_type': 'TEXT', 'storage': 'scalar', 'optional': True, 'inferred': True, 'note': 'Observed document property; no declared validation/type in uploaded source.'})
        else:
            collection['schema_status'] = 'declared SimpleSchema'
    return collections, attached


def quote(identifier):
    return '"' + identifier.replace('"', '""') + '"'


def generate(source):
    files = sorted(source.glob('*.js'))
    collections = {}
    inventory = []
    watchable = []
    for path in files:
        discovered, mixins = extract_source(path)
        collections.update(discovered)
        inventory.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'collections': sorted(discovered), 'role': 'schema mixin' if mixins else ('collection model' if discovered else 'helper/server/import/export code; no separate collection declaration')})
        if path.name == 'watchable.js':
            watchable = mixins
    if watchable:
        for name, mixin in [('cards', watchable[0]), ('lists', watchable[0]), ('boards', watchable[1])]:
            for field, descriptor in mixin.items():
                descriptor = dict(descriptor, source_file='watchable.js')
                collections[name]['fields'][field] = descriptor
    source_collection_count = len(collections)
    # Explicit game extensions requested by the user; no workspace model was
    # present in the archive, so these are identified separately from its API.
    def extension_field(name, source_type):
        return {'name': name, 'source_type': source_type, 'sqlite_type': {'Number': 'REAL', 'Integer': 'INTEGER', 'Boolean': 'INTEGER'}.get(source_type, 'TEXT'), 'storage': 'json' if source_type in ['Array', 'Object'] else 'scalar', 'optional': True, 'game_extension': True}
    collections['workspaces'] = {'name': 'workspaces', 'symbol': 'GameWorkspaces', 'file': '(game extension)', 'declaration': 'game extension: one office room per workspace', 'schema_status': 'explicit game extension; absent from uploaded models.zip', 'fields': {name: extension_field(name, kind) for name, kind in {'_id': 'String', 'orgId': 'String', 'floorId': 'String', 'name': 'String', 'title': 'String', 'room_number': 'String', 'floor': 'Number', 'slot_index': 'Integer', 'deleted': 'Boolean', 'in_pocket': 'Boolean', 'position': 'Object', 'document_json': 'Object'}.items()}}
    collections['floors'] = {'name': 'floors', 'symbol': 'GameFloors', 'file': '(game extension)', 'declaration': 'game extension: editable building floors', 'schema_status': 'explicit game extension; absent from uploaded models.zip', 'fields': {name: extension_field(name, kind) for name, kind in {'_id': 'String', 'orgId': 'String', 'name': 'String', 'title': 'String', 'number': 'Integer', 'deleted': 'Boolean', 'in_pocket': 'Boolean'}.items()}}
    for name, kind in [('workspaceId', 'String'), ('orgIds', 'Array')]:
        collections['boards']['fields'][name] = extension_field(name, kind)
    for name in ['orgId', 'workspaceId']:
        collections['team']['fields'][name] = extension_field(name, 'String')
    for collection in collections.values():
        collection['fields'].setdefault('_id', {'name': '_id', 'source_type': 'String', 'sqlite_type': 'TEXT', 'storage': 'scalar', 'optional': False, 'implicit': True, 'note': 'Mongo document identity'})
        collection['columns'] = {name: spec for name, spec in collection['fields'].items() if '.' not in name}
        collection['nested_fields'] = {name: spec for name, spec in collection['fields'].items() if '.' in name}
        collection['relationships'] = [{'field': name, 'target': {'boardId': 'boards', 'cardId': 'cards', 'listId': 'lists', 'swimlaneId': 'swimlanes', 'userId': 'users', 'checklistId': 'checklists', 'commentId': 'card_comments', 'orgId': 'org', 'teamId': 'team', 'ruleId': 'rules', 'triggerId': 'triggers', 'actionId': 'actions'}[name], 'enforcement': 'logical; no foreign key into incomplete external collections'} for name in collection['columns'] if name in ['boardId', 'cardId', 'listId', 'swimlaneId', 'userId', 'checklistId', 'commentId', 'orgId', 'teamId', 'ruleId', 'triggerId', 'actionId']]
    extension_tables = {'model_translations': {'columns': {name: 'TEXT' for name in ['collection', 'document_id', 'field', 'language', 'value']}, 'primary_key': ['collection', 'document_id', 'field', 'language']}, 'game_model_projection': {'columns': {'collection': 'TEXT', 'document_id': 'TEXT'}, 'primary_key': ['collection', 'document_id']}}
    result = {'format_version': 1, 'source': 'user-provided models.zip', 'source_file_count': len(files), 'source_collection_count': source_collection_count, 'collection_count': len(collections), 'game_extensions': ['workspaces', 'floors', 'boards.workspaceId', 'boards.orgIds', 'team.orgId', 'team.workspaceId', 'model_translations', 'game_model_projection'], 'extension_tables': extension_tables, 'type_mapping': {'String': 'TEXT', 'Boolean': 'INTEGER', 'Date': 'TEXT (ISO 8601)', 'Number': 'REAL', 'Array': 'TEXT (JSON)', 'Object': 'TEXT (JSON)'}, 'files': inventory, 'collections': [collections[name] for name in sorted(collections)]}
    sql = ['-- Generated from the user-provided models.zip; JavaScript was parsed, never executed.', '-- Standalone source-model schema. Runtime uses ensure_tables() to augment game tables.', '-- Required/optional and dynamic autoValue semantics remain in wekan_schema.json.', 'PRAGMA foreign_keys = ON;']
    for collection in result['collections']:
        sql.append('\n-- ' + collection['file'] + ': ' + collection['schema_status'])
        columns = []
        for name, spec in collection['columns'].items():
            columns.append('  ' + quote(name) + ' ' + spec['sqlite_type'] + (' UNIQUE' if name == '_id' else ''))
        sql.append('CREATE TABLE IF NOT EXISTS ' + quote(collection['name']) + ' (\n' + ',\n'.join(columns) + '\n);')
        for relation in collection['relationships']:
            index = 'wekan_' + re.sub(r'\W', '_', collection['name']) + '_' + relation['field']
            sql.append('CREATE INDEX IF NOT EXISTS ' + quote(index) + ' ON ' + quote(collection['name']) + '(' + quote(relation['field']) + ');')
    sql.append('\nCREATE TABLE IF NOT EXISTS model_translations (collection TEXT NOT NULL, document_id TEXT NOT NULL, field TEXT NOT NULL, language TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(collection, document_id, field, language));')
    sql.append('CREATE TABLE IF NOT EXISTS game_model_projection (collection TEXT NOT NULL, document_id TEXT NOT NULL, PRIMARY KEY(collection, document_id));')
    (ROOT / 'data/wekan_schema.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    (ROOT / 'data/wekan_schema.sql').write_text('\n'.join(sql) + '\n')
    connection = sqlite3.connect(':memory:')
    connection.executescript('\n'.join(sql))
    for collection in result['collections']:
        actual = {row[1] for row in connection.execute('PRAGMA table_info(' + quote(collection['name']) + ')')}
        assert actual == set(collection['columns']), (collection['name'], actual ^ set(collection['columns']))
        for path in collection['fields']:
            assert path.split('.')[0] in actual, (collection['name'], path)
    connection.executescript('\n'.join(sql))
    assert connection.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    print(json.dumps({'files': len(files), 'collections': len(collections), 'fields': sum(len(c['fields']) for c in collections.values()), 'columns': sum(len(c['columns']) for c in collections.values()), 'sqlite_coverage': 'passed', 'idempotent': True}))
    return result


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python tools/generate_schema.py /path/to/extracted/models')
    generate(Path(sys.argv[1]))
