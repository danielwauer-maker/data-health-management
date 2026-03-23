query 53141 "DH Vendor Duplicate Email"
{
    QueryType = Normal;

    elements
    {
        dataitem(Vendor; Vendor)
        {
            column(Email; "E-Mail")
            {
            }

            column(VendorCount)
            {
                Method = Count;
            }

            filter(EmailFilter; "E-Mail")
            {
            }
        }
    }
}