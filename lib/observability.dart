// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank observability — re-exported from sentin8.
//
// EBankLogger is re-exported as an alias for AppLogger.
export 'package:sentin8/sentin8.dart'
    show AppLogger, LogEntry, generateCorrelationId;

import 'package:sentin8/sentin8.dart';

/// Backward-compatible alias.
typedef EBankLogger = AppLogger;
