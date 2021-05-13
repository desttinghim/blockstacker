export default function getCrossDBEnv(getGlobalInstance) {
    const getMem = () => getGlobalInstance().exports.memory.buffer;
    const utf8decoder = new TextDecoder();
    const read_utf8_string = (ptr, len) =>
        utf8decoder.decode(new Uint8Array(getMem(), ptr, len));

    // List objects, exposed so database transactions can be given a list of store names
    const lists = {};
    let next_list_id = 1;

    const makeListHandle = (list) => {
        const id = next_list_id;
        next_list_id += 1;
        lists[id] = list;
        return id;
    };

    const getList = (listHandle) => {
        return lists[listHandle];
    };

    const destroyListHandle = (listHandle) => {
        delete lists[listHandle];
    };

    const databases = {};
    let next_database_id = 1;

    const makeDatabaseHandle = (database) => {
        const id = next_database_id;
        next_database_id += 1;
        databases[id] = database;
        return id;
    };

    const getDatabase = (databaseHandle) => {
        return databases[databaseHandle];
    };

    const destroyDatabaseHandle = (databaseHandle) => {
        delete databases[databaseHandle];
    };

    const transactions = {};
    let next_transaction_id = 1;

    const makeTransactionHandle = (transaction) => {
        const id = next_transaction_id;
        next_transaction_id += 1;
        transactions[id] = transaction;
        return id;
    };

    const getTransaction = (transactionHandle) => {
        return transactions[transactionHandle];
    };

    const destroyTransactionHandle = (transactionHandle) => {
        delete transactions[transactionHandle];
    };

    const stores = {};
    let next_store_id = 1;

    const makeStoreHandle = (store) => {
        const id = next_store_id;
        next_store_id += 1;
        stores[id] = store;
        return id;
    };

    const getStore = (storeHandle) => {
        return stores[storeHandle];
    };

    const destroyStoreHandle = (storeHandle) => {
        delete stores[storeHandle];
    };

    const cursors = {};
    let next_cursor_id = 1;

    const makeCursorHandle = (cursor) => {
        const id = next_cursor_id;
        next_cursor_id += 1;
        cursors[id] = cursor;
        return id;
    };

    const getCursorHandle = (cursorHandle) => {
        return cursors[cursorHandle];
    };

    const setCursorHandle = (cursorHandle, cursor) => {
        cursors[cursorHandle] = cursor;
    };

    const destroyCursorHandle = (cursorHandle) => {
        delete cursors[cursorHandle];
    };

    return {
        databaseOpen(namePtr, nameLen, version, frame, userdata, dbout) {
            const name = read_utf8_string(namePtr, nameLen);

            const request = window.indexedDB.open(name, version);
            request.onerror = (event) => {
                getGlobalInstance().exports.crossdb_finishOpen(
                    frame,
                    userdata,
                    dbout,
                    null
                );
            };
            request.onsuccess = (event) => {
                const handle = makeDatabaseHandle(event.target.result);
                getGlobalInstance().exports.crossdb_finishOpen(
                    frame,
                    userdata,
                    dbout,
                    handle
                );
            };
            request.onupgradeneeded = (event) => {
                const dbHandle = makeDatabaseHandle(event.target.result);
                getGlobalInstance().exports.crossdb_upgradeNeeded(
                    userdata,
                    dbHandle,
                    event.oldVersion,
                    event.newVersion
                );
                destroyDatabaseHandle(dbHandle);
            };
        },

        databaseDelete(namePtr, nameLen) {
            const name = read_utf8_string(namePtr, nameLen);

            const request = window.indexedDB.deleteDatabase(name);
        },

        databaseCreateStore(dbHandle, storeNamePtr, storeNameLen) {
            const db = getDatabase(dbHandle);
            const name = read_utf8_string(storeNamePtr, storeNameLen);

            db.createObjectStore(name, { keyPath: "key" });
        },

        databaseBegin(dbHandle, storeListHandle) {
            const db = getDatabase(dbHandle);
            const storeList = getList(storeListHandle);
            const txn = db.transaction(storeList, "readwrite");

            return makeTransactionHandle(txn);
        },

        listInit() {
            return makeListHandle([]);
        },

        listAppendString(listHandle, strPtr, strLen) {
            const list = getList(listHandle);
            const str = read_utf8_string(strPtr, strLen);
            list.push(str);
        },

        listFree(listHandle) {
            destroyListHandle(listHandle);
        },

        transactionStore(txnHandle, storeNamePtr, storeNameLen) {
            const txn = getTransaction(txnHandle);
            const name = read_utf8_string(storeNamePtr, storeNameLen);

            return makeStoreHandle(txn.objectStore(name));
        },

        transactionDeinit(txnHandle, framePtr) {
            const txn = getTransaction(txnHandle);
            txn.abort();
            destroyTransactionHandle(txnHandle);
        },

        transactionCommit(txnHandle, framePtr) {
            const txn = getTransaction(txnHandle);

            txn.oncomplete = () => {
                getGlobalInstance().exports.crossdb_finish_transactionCommit(
                    framePtr
                );
            };

            txn.onerror = (event) => {
                getGlobalInstance().exports.crossdb_finish_transactionCommit(
                    framePtr
                );
            };

            txn.commit();
            destroyTransactionHandle(txnHandle);
        },

        storeRelease(storeHandle) {
            destroyStoreHandle(storeHandle);
        },

        storePut(storeHandle, keyPtr, keyLen, valPtr, valLen) {
            const store = getStore(storeHandle);
            const key = new Uint8Array(getMem(), keyPtr, keyLen);
            const val = new Uint8Array(getMem(), valPtr, valLen);

            store.put({ key: key, value: val });
        },

        storeGet(storeHandle, framePtr, keyPtr, keyLen, allocator, valOut) {
            const store = getStore(storeHandle);
            const key = new Uint8Array(getMem(), keyPtr, keyLen);

            let request = store.get(key);
            request.onsuccess = (event) => {
                let valuePtr = null;
                let length = 0;

                if (request.result) {
                    // TODO: send error to wasm
                    length = request.result.value.byteLength;
                    valuePtr = getGlobalInstance().exports.crossdb_alloc(
                        allocator,
                        length
                    );

                    const val = new Uint8Array(getMem(), valuePtr, length);
                    val.set(request.result.value);
                }

                getGlobalInstance().exports.crossdb_finish_storeGet(
                    framePtr,
                    valOut,
                    valuePtr,
                    length
                );
            };
        },

        storeCursor(storeHandle, framePtr, cursorOutPtr) {
            const store = getStore(storeHandle);

            const cursorHandle = makeCursorHandle({
                framePtr,
                cursor: null,
            });

            const cursorOut = new Uint32Array(getMem(), cursorOutPtr, 1);
            cursorOut[0] = cursorHandle;

            let request = store.openCursor();
            request.onsuccess = (event) => {
                // Get the frame pointer we should resume to
                const { framePtr } = getCursorHandle(cursorHandle);

                // Null out the frame pointer and store the cursor for retriving the value in `cursorContinue`
                setCursorHandle(cursorHandle, {
                    framePtr: null,
                    cursor: event.target.result,
                });

                getGlobalInstance().exports.crossdb_resume(framePtr);
            };
        },

        cursorContinue(
            cursorHandle,
            framePtr,
            allocator,
            keyOutPtrPtr,
            keyOutLenPtr,
            valOutPtrPtr,
            valOutLenPtr
        ) {
            const { cursor } = getCursorHandle(cursorHandle);
            setCursorHandle(cursorHandle, { cursor: null, framePtr });
            if (cursor) {
                const key_len =cursor.value.key.byteLength;
                const val_len =cursor.value.value.byteLength;

                const key_ptr = getGlobalInstance().exports.crossdb_alloc(
                    allocator,
                    key_len
                );
                const val_ptr = getGlobalInstance().exports.crossdb_alloc(
                    allocator,
                    val_len
                );

                const key = new Uint8Array(getMem(), key_ptr, key_len);
                const val = new Uint8Array(getMem(), val_ptr, val_len);

                key.set(cursor.value.key);
                val.set(cursor.value.value);

                new Uint32Array(getMem(), keyOutPtrPtr, 1)[0] = key_ptr;
                new Uint32Array(getMem(), keyOutLenPtr, 1)[0] = key_len;
                new Uint32Array(getMem(), valOutPtrPtr, 1)[0] = val_ptr;
                new Uint32Array(getMem(), valOutLenPtr, 1)[0] = val_len;

                cursor.continue();
            } else {
                getGlobalInstance().exports.crossdb_resume(framePtr);
            }
        },

        cursorDeinit(cursorHandle) {
            destroyCursorHandle(cursorHandle);
        },
    };
}
