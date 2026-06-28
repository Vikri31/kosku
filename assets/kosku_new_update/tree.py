print("Program dimulai")

import os

def tree(path, prefix=""):
    items = sorted(os.listdir(path))

    for index, item in enumerate(items):
        item_path = os.path.join(path, item)
        is_last = index == len(items) - 1

        connector = "└── " if is_last else "├── "
        print(prefix + connector + item)

        if os.path.isdir(item_path):
            extension = "    " if is_last else "│   "
            tree(item_path, prefix + extension)

if __name__ == "__main__":
    folder = input("Masukkan path folder: ")
    print(folder)
    tree(folder)