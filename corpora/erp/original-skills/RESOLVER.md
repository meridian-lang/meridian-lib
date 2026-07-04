# ERP Resolver

Routes an ERP operator request to the synthetic ERP skill that owns it.

## Dispatch table

| trigger phrase | skill |
| --- | --- |
| process open orders | placeorder |
| fulfill ERP orders | fulfillorder |
| run invoices | invoicerun |
| run dunning | dunning |
| restock short products | restock |
| receive inbound shipment | receiveshipment |
| cancel blocked orders | cancelorder |
| month-end close | monthendclose |

## Workflow

Look up the skill corresponding to the trigger phrase and emit the selected
skill id.
