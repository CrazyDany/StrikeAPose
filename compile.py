#!/usr/bin/env python3
"""
Компилятор мода для SM64CoopDX.
Поддерживает:
- преобразование вложенных папок в плоскую структуру с подчёркиваниями,
- игнорируемые папки (копируются как есть),
- приоритетные папки (добавляют числовой префикс для порядка загрузки),
- исключаемые папки и файлы (полностью игнорируются, не копируются).
"""

import os
import sys
import json
import shutil
import argparse
import fnmatch
import stat
from pathlib import Path


def load_config(config_path):
    if not os.path.isfile(config_path):
        return {}
    with open(config_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def on_rmtree_error(func, path, exc_info):
    """Обработчик ошибок для shutil.rmtree: снимает атрибут 'только для чтения' и повторяет попытку."""
    if not os.access(path, os.W_OK):
        os.chmod(path, stat.S_IWUSR)
        func(path)
    else:
        raise


def copy_ignored_folder(src_root, src_path, dst_root, dst_path):
    src_full = os.path.join(src_root, src_path)
    dst_full = os.path.join(dst_root, dst_path)
    if os.path.exists(dst_full):
        shutil.rmtree(dst_full, onerror=on_rmtree_error)
    shutil.copytree(src_full, dst_full)


def transform_filename(rel_path, priority_prefix=None):
    parts = rel_path.split(os.sep)
    if not parts:
        return rel_path
    filename = parts[-1]
    folders = parts[:-1]
    depth = len(folders)

    base_name = '_'.join(parts)
    prefix_underscores = '_' * depth
    new_name = prefix_underscores + base_name

    if priority_prefix:
        new_name = priority_prefix + new_name
    return new_name


def is_path_in_ignored(rel_path, ignore_folders):
    first_part = rel_path.split(os.sep)[0]
    return first_part in ignore_folders


def get_priority_for_path(rel_path, priority_folders):
    first_part = rel_path.split(os.sep)[0]
    if first_part in priority_folders:
        order = priority_folders[first_part]
        return f"{order:02d}_"
    return None


def should_exclude(rel_path, exclude_folders, exclude_files):
    """Проверяет, должен ли элемент (файл или папка) быть полностью исключён."""
    if not exclude_folders and not exclude_files:
        return False
    parts = rel_path.split(os.sep)
    if parts and parts[0] in exclude_folders:
        return True
 
    filename = os.path.basename(rel_path)
    for pattern in exclude_files:
        if fnmatch.fnmatch(rel_path, pattern) or fnmatch.fnmatch(filename, pattern):
            return True
    return False


def should_ignore_file(rel_path, ignore_patterns):
    if not ignore_patterns:
        return False
    filename = os.path.basename(rel_path)
    for pattern in ignore_patterns:
        if fnmatch.fnmatch(rel_path, pattern):
            return True
        if fnmatch.fnmatch(filename, pattern):
            return True
    return False


def main():
    parser = argparse.ArgumentParser(
        description="Компиляция мода для SM64CoopDX из рабочей области."
    )
    parser.add_argument(
        '--source', '-s',
        required=True,
        help="Путь к рабочей области (исходная папка мода)"
    )
    parser.add_argument(
        '--target', '-t',
        required=True,
        help="Путь к папке mods в билде SM64CoopDX (например, ./mods/MyMod)"
    )
    parser.add_argument(
        '--config', '-c',
        help="Путь к JSON-конфигу (если не указан, ищется build_config.json в исходной папке)"
    )
    parser.add_argument(
        '--clean',
        action='store_true',
        help="Удалить целевую папку перед копированием"
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help="Выводить подробный лог"
    )
    args = parser.parse_args()

    src_root = os.path.abspath(args.source)
    dst_root = os.path.abspath(args.target)

    if not os.path.isdir(src_root):
        print(f"Ошибка: исходная папка '{src_root}' не существует.")
        sys.exit(1)

    # Конфиг
    if args.config:
        config_path = args.config
    else:
        config_path = os.path.join(src_root, 'build_config.json')
    config = load_config(config_path)

    ignore_folders = config.get('ignore_folders', [])
    priority_folders = config.get('priority_folders', {})
    ignore_patterns = config.get('ignore_files', [])
    exclude_folders = config.get('exclude_folders', [])
    exclude_files = config.get('exclude_files', [])

    if args.verbose:
        print(f"Конфиг загружен: {config_path}")
        print(f"Игнорируемые папки (копируются как есть): {ignore_folders}")
        print(f"Приоритетные папки: {priority_folders}")
        print(f"Игнорируемые файлы (не копируются): {ignore_patterns}")
        print(f"Исключаемые папки (полностью пропускаются): {exclude_folders}")
        print(f"Исключаемые файлы (полностью пропускаются): {exclude_files}")

    if args.clean and os.path.exists(dst_root):
        shutil.rmtree(dst_root, onerror=on_rmtree_error)

    os.makedirs(dst_root, exist_ok=True)

    copied_count = 0
    ignored_count = 0
    excluded_count = 0

    for root, dirs, files in os.walk(src_root):
        rel_root = os.path.relpath(root, src_root)
        if rel_root == '.':
            rel_root = ''

        if rel_root and should_exclude(rel_root, exclude_folders, []):
            if args.verbose:
                print(f"Исключена папка: {rel_root}")
            excluded_count += 1
            continue

        if rel_root and is_path_in_ignored(rel_root, ignore_folders):
            copy_ignored_folder(src_root, rel_root, dst_root, rel_root)
            if args.verbose:
                print(f"Скопирована игнорируемая папка: {rel_root}")
            continue

        for file in files:
            src_file = os.path.join(root, file)
            rel_file = os.path.join(rel_root, file) if rel_root else file

            if should_exclude(rel_file, [], exclude_files):
                if args.verbose:
                    print(f"Исключён файл: {rel_file}")
                excluded_count += 1
                continue

            if should_ignore_file(rel_file, ignore_patterns):
                if args.verbose:
                    print(f"Игнорируется файл: {rel_file}")
                ignored_count += 1
                continue

            priority_prefix = get_priority_for_path(rel_file, priority_folders)
            new_name = transform_filename(rel_file, priority_prefix)

            dst_file = os.path.join(dst_root, new_name)
            shutil.copy2(src_file, dst_file)
            copied_count += 1
            if args.verbose:
                print(f"Скопирован: {rel_file} -> {new_name}")

    print(f"Сборка завершена. Скопировано: {copied_count}, игнорировано: {ignored_count}, исключено: {excluded_count}")
    print(f"Мод собран в {dst_root}")


if __name__ == "__main__":
    main()